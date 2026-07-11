<?php

/**
 * Guest M-Pesa Payment Controller
 *
 * Allows unauthenticated users on a MikroTik captive portal to buy internet
 * access with M-Pesa STK Push and be logged in automatically after payment.
 */

$action = $routes['1'] ?? 'init';
$ui->assign('_system_menu', 'mpesa_guest');

switch ($action) {
    case 'init':
        // Show the guest payment form.
        $ui->assign('_title', Lang::T('Buy Internet Access'));

        // Capture captive portal parameters.
        $mac = alphanumeric(_get('nux-mac'), ':.-');
        $ip = alphanumeric(_get('nux-ip'), '.:');
        $router = alphanumeric(_get('nux-router'));
        $dst = _get('dst');
        $linkLogin = _get('link-login-only');

        // Persist in session so we can retrieve them after the payment redirect.
        $_SESSION['mpesa_guest_mac'] = $mac;
        $_SESSION['mpesa_guest_ip'] = $ip;
        $_SESSION['mpesa_guest_router'] = $router;
        $_SESSION['mpesa_guest_dst'] = $dst;
        $_SESSION['mpesa_guest_link_login'] = $linkLogin;

        // Resolve router session (same logic as login.php/order.php).
        if (!empty($router)) {
            if ($router == 'radius') {
                $_SESSION['nux-router'] = 'radius';
            } else {
                $r = ORM::for_table('tbl_routers')->find_one($router);
                if ($r) {
                    $_SESSION['nux-router'] = $r['id'];
                }
            }
        }

        // Load available prepaid plans.
        $plans = [];
        if (!empty($_SESSION['nux-router']) && $_SESSION['nux-router'] != 'radius') {
            $routers = ORM::for_table('tbl_routers')->where('id', $_SESSION['nux-router'])->find_many();
            $rs = [];
            foreach ($routers as $r) {
                $rs[] = $r['name'];
            }
            $plans = ORM::for_table('tbl_plans')
                ->where('enabled', '1')
                ->where('prepaid', 'yes')
                ->where_in('routers', $rs)
                ->where('is_radius', 0)
                ->find_many();
        } elseif (!empty($_SESSION['nux-router']) && $_SESSION['nux-router'] == 'radius') {
            $plans = ORM::for_table('tbl_plans')
                ->where('enabled', '1')
                ->where('prepaid', 'yes')
                ->where('is_radius', 1)
                ->find_many();
        } else {
            $plans = ORM::for_table('tbl_plans')
                ->where('enabled', '1')
                ->where('prepaid', 'yes')
                ->find_many();
        }

        $ui->assign('plans', $plans);
        $ui->assign('mac', $mac);
        $ui->assign('ip', $ip);
        $ui->assign('router', $router);
        $ui->assign('dst', $dst);
        $ui->assign('link_login', $linkLogin);
        $ui->assign('csrf_token', Csrf::generateAndStoreToken());
        $ui->display('customer/mpesa_guest.tpl');
        break;

    case 'pay':
        // Validate form.
        if (!Csrf::check(_post('csrf_token'))) {
            _msglog('e', Lang::T('Invalid or Expired CSRF Token'));
            r2(getUrl('mpesa_guest/init'));
        }

        $phone = mpesa_normalize_phone(_post('phone'));
        if (!$phone) {
            _msglog('e', Lang::T('Please enter a valid phone number'));
            r2(getUrl('mpesa_guest/init'));
        }

        $planId = (int) _post('plan');
        $plan = ORM::for_table('tbl_plans')->find_one($planId);
        if (!$plan || $plan['enabled'] != '1') {
            _msglog('e', Lang::T('Plan not found'));
            r2(getUrl('mpesa_guest/init'));
        }

        $routerName = '';
        $routerId = 0;
        if ($plan['is_radius'] == '1') {
            $routerName = 'radius';
            $routerId = 0;
        } else {
            $router = ORM::for_table('tbl_routers')->where('name', $plan['routers'])->find_one();
            if (!$router) {
                _msglog('e', Lang::T('Router not found'));
                r2(getUrl('mpesa_guest/init'));
            }
            $routerName = $router['name'];
            $routerId = $router['id'];
        }

        // Prevent duplicate pending transactions for the same phone.
        $existing = ORM::for_table('tbl_payment_gateway')
            ->where('username', $phone)
            ->where('gateway', 'mpesa')
            ->where('status', 1)
            ->find_one();
        if ($existing) {
            r2(getUrl('mpesa_guest/wait/' . $existing['id']), 'w', Lang::T("You already have a pending payment"));
        }

        // Create the transaction record.
        $d = ORM::for_table('tbl_payment_gateway')->create();
        $d->username = $phone;
        $d->user_id = 0;
        $d->gateway = 'mpesa';
        $d->plan_id = $plan['id'];
        $d->plan_name = $plan['name_plan'];
        $d->routers_id = $routerId;
        $d->routers = $routerName;
        $d->price = $plan['price'];
        $d->payment_method = 'M-Pesa STK Push';
        $d->payment_channel = $phone;
        $d->created_date = date('Y-m-d H:i:s');
        $d->status = 1;
        $d->save();
        $trxId = $d->id();

        // Store guest context for post-payment auto-auth.
        $context = [
            'mac' => $_SESSION['mpesa_guest_mac'] ?? '',
            'ip' => $_SESSION['mpesa_guest_ip'] ?? '',
            'router' => $routerName,
            'dst' => $_SESSION['mpesa_guest_dst'] ?? '',
            'link_login' => $_SESSION['mpesa_guest_link_login'] ?? '',
            'plan_id' => $plan['id'],
        ];
        $meta = ORM::for_table('tbl_meta')->create();
        $meta->tbl = 'tbl_payment_gateway';
        $meta->tbl_id = $trxId;
        $meta->name = 'guest_context';
        $meta->value = json_encode($context);
        $meta->save();

        // Build a synthetic guest user for the gateway function.
        $guestUser = [
            'id' => 0,
            'username' => $phone,
            'phonenumber' => $phone,
        ];

        // Ensure the gateway file is loaded.
        $gatewayFile = $PAYMENTGATEWAY_PATH . DIRECTORY_SEPARATOR . 'mpesa.php';
        if (!file_exists($gatewayFile)) {
            _msglog('e', Lang::T('M-Pesa gateway not installed'));
            r2(getUrl('mpesa_guest/init'));
        }
        require_once $gatewayFile;

        // Validate gateway configuration and initiate STK push.
        mpesa_validate_config();
        mpesa_create_transaction($d, $guestUser);

        // If the gateway did not redirect, go to the waiting page.
        r2(getUrl('mpesa_guest/wait/' . $trxId), 's', Lang::T('STK push sent. Please check your phone.'));
        break;

    case 'wait':
        // Show polling page for the guest.
        $trxId = (int) $routes['2'];
        $trx = ORM::for_table('tbl_payment_gateway')->find_one($trxId);
        if (!$trx || $trx['gateway'] != 'mpesa') {
            _msglog('e', Lang::T('Transaction not found'));
            r2(getUrl('mpesa_guest/init'));
        }

        // Load the customer (created by callback) and credentials fallback.
        $user = ORM::for_table('tbl_customers')->where('username', $trx['username'])->find_one();
        $password = '';
        if ($user) {
            $meta = ORM::for_table('tbl_meta')
                ->where('tbl', 'tbl_customers')
                ->where('tbl_id', $user['id'])
                ->where('name', 'mpesa_password')
                ->find_one();
            if ($meta) {
                $password = $meta['value'];
            }
        }

        $context = ORM::for_table('tbl_meta')
            ->where('tbl', 'tbl_payment_gateway')
            ->where('tbl_id', $trx['id'])
            ->where('name', 'guest_context')
            ->find_one();

        $ui->assign('_title', Lang::T('Processing Payment'));
        $ui->assign('trx', $trx);
        $ui->assign('user', $user);
        $ui->assign('password', $password);
        $ui->assign('context', $context ? json_decode($context['value'], true) : []);
        $ui->display('customer/mpesa_guest_wait.tpl');
        break;

    case 'check':
        // AJAX endpoint for the polling page.
        header('Content-Type: application/json');
        $trxId = (int) $routes['2'];
        $trx = ORM::for_table('tbl_payment_gateway')->find_one($trxId);
        if (!$trx || $trx['gateway'] != 'mpesa') {
            echo json_encode(['status' => 'error', 'message' => Lang::T('Transaction not found')]);
            exit;
        }

        if ($trx['status'] == 2) {
            // Already paid; ensure activation has run.
            require_once $PAYMENTGATEWAY_PATH . DIRECTORY_SEPARATOR . 'mpesa.php';
            $user = mpesa_process_successful_payment($trx);

            $password = '';
            if ($user) {
                $meta = ORM::for_table('tbl_meta')
                    ->where('tbl', 'tbl_customers')
                    ->where('tbl_id', $user['id'])
                    ->where('name', 'mpesa_password')
                    ->find_one();
                if ($meta) {
                    $password = $meta['value'];
                }
            }

            $context = ORM::for_table('tbl_meta')
                ->where('tbl', 'tbl_payment_gateway')
                ->where('tbl_id', $trx['id'])
                ->where('name', 'guest_context')
                ->find_one();

            $ctx = $context ? json_decode($context['value'], true) : [];
            $dst = $ctx['dst'] ?? '';

            echo json_encode([
                'status' => 'paid',
                'username' => $user['username'] ?? '',
                'password' => $password,
                'dst' => $dst,
                'message' => Lang::T('Payment successful. You are being connected.'),
            ]);
            exit;
        } elseif ($trx['status'] == 3) {
            echo json_encode(['status' => 'failed', 'message' => Lang::T('Payment failed. Please try again.')]);
            exit;
        } elseif ($trx['status'] == 4) {
            echo json_encode(['status' => 'cancelled', 'message' => Lang::T('Payment was cancelled.')]);
            exit;
        }

        echo json_encode(['status' => 'pending', 'message' => Lang::T('Waiting for M-Pesa confirmation...')]);
        exit;

    default:
        r2(getUrl('mpesa_guest/init'));
}
