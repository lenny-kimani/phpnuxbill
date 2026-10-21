#!/usr/bin/env bash
set -euo pipefail

# M-Pesa + RADIUS end-to-end test script for PHPNuxBill Docker environment.
#
# This script simulates a successful M-Pesa STK push payment by creating a
# pending payment record and processing it with the same code path the real
# M-Pesa callback uses. It then verifies the generated credentials can
# authenticate against the FreeRADIUS server and that the session expires
# according to the configured package time.
#
# Usage:
#   ./test_mpesa_radius.sh [--plan-id ID] [--phone PHONE] [--wait SECONDS]
#
# Defaults: plan id 7, sandbox phone 254708374149, wait = plan validity + 20s

PLAN_ID=7
PHONE="254708374149"
WAIT_SECONDS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --plan-id)
            PLAN_ID="$2"
            shift 2
            ;;
        --phone)
            PHONE="$2"
            shift 2
            ;;
        --wait)
            WAIT_SECONDS="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Usage: $0 [--plan-id ID] [--phone PHONE] [--wait SECONDS]" >&2
            exit 1
            ;;
    esac
done

if [[ -z "${WAIT_SECONDS:-}" ]]; then
    WAIT_SECONDS=$(docker exec rofa-phpnuxbill php -r '
        require "/var/www/html/init.php";
        $p = ORM::for_table("tbl_plans")->find_one('"$PLAN_ID"');
        if (!$p) exit(1);
        $mul = ["Mins"=>60,"Hrs"=>3600,"Days"=>86400,"Months"=>2592000];
        echo (int)($p["validity"] * ($mul[$p["validity_unit"]] ?? 60)) + 20;
    ' 2>/dev/null || echo 80)
fi

RADIUS_SECRET=$(grep RADIUS_SECRET /home/dev/Documents/projects/phpnuxbill/.env | cut -d= -f2)
MYSQL_ROOT_PASSWORD=$(grep MYSQL_ROOT_PASSWORD /home/dev/Documents/projects/phpnuxbill/.env | cut -d= -f2)

echo "=== M-Pesa + RADIUS end-to-end test ==="
echo "Plan ID: $PLAN_ID"
echo "Phone:   $PHONE"
echo "Wait:    ${WAIT_SECONDS}s"
echo

# Helper PHP script used to simulate the M-Pesa payment.
PHP_FILE=$(mktemp /tmp/test_radius_mpesa_helper.XXXXXX.php)
cat > "$PHP_FILE" <<'PHPEOF'
<?php
require_once "/var/www/html/init.php";
require_once "/var/www/html/system/paymentgateway/mpesa/mpesa.php";

$planId = (int)getenv("TEST_PLAN_ID");
$phone = getenv("TEST_PHONE") ?: "254708374149";

$plan = ORM::for_table("tbl_plans")->find_one($planId);
if (!$plan) { fwrite(STDERR, "Plan not found\n"); exit(1); }

$normalized = mpesa_normalize_phone($phone);
if (!$normalized) { fwrite(STDERR, "Invalid phone\n"); exit(1); }

// Clean previous test data for this phone
ORM::for_table("tbl_payment_gateway")->where("gateway", "mpesa")->where("username", $normalized)->delete_many();
ORM::for_table("tbl_customers")->where("username", $normalized)->delete_many();
ORM::for_table("tbl_user_recharges")->where("username", $normalized)->delete_many();
ORM::for_table("tbl_transactions")->where("username", $normalized)->delete_many();
ORM::for_table("rad_acct", "radius")->where("username", $normalized)->delete_many();

$d = ORM::for_table("tbl_payment_gateway")->create();
$d->username = $normalized;
$d->user_id = 0;
$d->gateway = "mpesa";
$d->plan_id = $plan["id"];
$d->plan_name = $plan["name_plan"];
$d->routers_id = 0;
$d->routers = "radius";
$d->price = $plan["price"];
$d->payment_method = "M-Pesa STK Push";
$d->payment_channel = $normalized;
$d->created_date = date("Y-m-d H:i:s");
$d->expired_date = date("Y-m-d H:i:s", strtotime("+15 minutes"));
$d->status = 1;
$d->gateway_trx_id = "test-" . time();
$d->save();

$user = mpesa_process_successful_payment($d);
if (!$user) { fwrite(STDERR, "Payment processing failed\n"); exit(1); }

$meta = ORM::for_table("tbl_meta")
    ->where("tbl", "tbl_customers")
    ->where("tbl_id", $user["id"])
    ->where("name", "mpesa_password")
    ->find_one();

$tur = ORM::for_table("tbl_user_recharges")->where("username", $normalized)->find_one();

echo json_encode([
    "username" => $user["username"],
    "password" => $meta ? $meta["value"] : "",
    "recharge_status" => $tur ? $tur["status"] : "",
    "expiration" => $tur ? ($tur["expiration"] . " " . $tur["time"]) : "",
    "plan_name" => $plan["name_plan"],
    "device" => $plan["device"],
]);
PHPEOF

# Step 1: simulate M-Pesa payment and create customer/recharge
echo "[1/5] Simulating M-Pesa payment..."
docker cp "$PHP_FILE" rofa-phpnuxbill:/var/www/html/system/test_radius_mpesa_helper.php
docker exec rofa-phpnuxbill chmod 644 /var/www/html/system/test_radius_mpesa_helper.php
PAYMENT_RESULT=$(docker exec rofa-phpnuxbill sh -c "cd /var/www/html/system && TEST_PLAN_ID=$PLAN_ID TEST_PHONE=$PHONE su -s /bin/sh www-data -c '/usr/local/bin/php test_radius_mpesa_helper.php'")
docker exec rofa-phpnuxbill rm -f /var/www/html/system/test_radius_mpesa_helper.php
rm -f "$PHP_FILE"

if [[ -z "$PAYMENT_RESULT" ]] || [[ "$PAYMENT_RESULT" != *"username"* ]]; then
    echo "ERROR: Payment simulation failed" >&2
    echo "$PAYMENT_RESULT" >&2
    exit 1
fi

USERNAME=$(echo "$PAYMENT_RESULT" | python3 -c 'import sys,json; print(json.load(sys.stdin)["username"])')
PASSWORD=$(echo "$PAYMENT_RESULT" | python3 -c 'import sys,json; print(json.load(sys.stdin)["password"])')
EXPIRATION=$(echo "$PAYMENT_RESULT" | python3 -c 'import sys,json; print(json.load(sys.stdin)["expiration"])')

echo "Created customer: $USERNAME"
echo "Password:         $PASSWORD"
echo "RADIUS recharge expires: $EXPIRATION"
echo

if [[ -z "$USERNAME" || -z "$PASSWORD" ]]; then
    echo "ERROR: Could not extract credentials" >&2
    exit 1
fi

# Step 2: initial RADIUS auth should succeed
echo "[2/5] Testing RADIUS authentication (expect Access-Accept)..."
AUTH1=$(docker exec rofa-coa sh -c "radtest '$USERNAME' '$PASSWORD' rofa-freeradius 0 '$RADIUS_SECRET' 2>&1" || true)
if echo "$AUTH1" | grep -q "Received Access-Accept"; then
    echo "PASS: Initial authentication accepted"
    echo "$AUTH1" | grep -E "Mikrotik-Rate-Limit|WISPr-Session-Terminate-Time|Reply-Message" | sed 's/^/  /'
else
    echo "FAIL: Initial authentication not accepted" >&2
    echo "$AUTH1" >&2
    exit 1
fi
echo

# Step 3: wait for package to expire
echo "[3/5] Waiting ${WAIT_SECONDS}s for package expiration/session timeout..."
sleep "$WAIT_SECONDS"
echo

# Step 4: subsequent RADIUS auth should fail
echo "[4/5] Testing RADIUS authentication after expiry (expect Access-Reject)..."
AUTH2=$(docker exec rofa-coa sh -c "radtest '$USERNAME' '$PASSWORD' rofa-freeradius 0 '$RADIUS_SECRET' 2>&1" || true)
if echo "$AUTH2" | grep -q "Received Access-Reject"; then
    echo "PASS: Re-authentication rejected after expiry"
    echo "$AUTH2" | grep -E "Reply-Message" | sed 's/^/  /'
else
    echo "FAIL: Re-authentication was not rejected" >&2
    echo "$AUTH2" >&2
    exit 1
fi
echo

# Step 5: cleanup
echo "[5/5] Cleaning up test customer, recharge and transactions..."
docker exec rofa-mysql mysql -uroot -p"$MYSQL_ROOT_PASSWORD" rofa_nuxbill -e "
    DELETE FROM tbl_payment_gateway WHERE gateway='mpesa' AND username='$USERNAME';
    DELETE FROM tbl_customers WHERE username='$USERNAME';
    DELETE FROM tbl_user_recharges WHERE username='$USERNAME';
    DELETE FROM tbl_transactions WHERE username='$USERNAME';
" >/dev/null 2>&1 || true

echo "=== All checks passed ==="
