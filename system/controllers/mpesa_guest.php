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

        // Capture captive portal parameters — only overwrite values that are
        // actually present. "Try Again"/"Back to packages" links reload this
        // page WITHOUT the nux-*/link-login params, and blindly writing the
        // empties wiped a previously captured portal context (the reason
        // auto-auth skipped with "link_login missing" and the login button
        // disappeared on retry attempts).
        $mac = alphanumeric(_get('nux-mac'), ':.-');
        $ip = alphanumeric(_get('nux-ip'), '.:');
        $router = alphanumeric(_get('nux-router'));
        $dst = _get('dst');
        $linkLogin = _get('link-login-only');

        if ($mac !== '') {
            $_SESSION['mpesa_guest_mac'] = $mac;
        }
        if ($ip !== '') {
            $_SESSION['mpesa_guest_ip'] = $ip;
        }
        if ($router !== '') {
            $_SESSION['mpesa_guest_router'] = $router;
        }
        if ($dst !== '') {
            $_SESSION['mpesa_guest_dst'] = $dst;
        }
        if ($linkLogin !== '') {
            $_SESSION['mpesa_guest_link_login'] = $linkLogin;
        }

        // Read back (may come from an earlier portal visit).
        $mac = $_SESSION['mpesa_guest_mac'] ?? '';
        $ip = $_SESSION['mpesa_guest_ip'] ?? '';
        $router = $_SESSION['mpesa_guest_router'] ?? '';
        $dst = $_SESSION['mpesa_guest_dst'] ?? '';
        $linkLogin = $_SESSION['mpesa_guest_link_login'] ?? '';

        // Resolve router session (same logic as login.php/order.php).
        if (!empty($router)) {
            if ($router == 'radius') {
                $_SESSION['nux-router'] = 'radius';
            } else {
                $r = is_numeric($router)
                    ? ORM::for_table('tbl_routers')->find_one((int) $router)
                    : ORM::for_table('tbl_routers')->where('name', $router)->find_one();
                if ($r) {
                    $_SESSION['nux-router'] = $r['id'];
                } else {
                    unset($_SESSION['nux-router']);
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
        // Load the M-Pesa gateway functions before using them.
        $gatewayFile = $PAYMENTGATEWAY_PATH . DIRECTORY_SEPARATOR . 'mpesa.php';
        if (!file_exists($gatewayFile)) {
            _msglog('e', Lang::T('M-Pesa gateway not installed'));
            r2(getUrl('mpesa_guest/init'));
        }
        require_once $gatewayFile;

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

        // Prevent duplicate pending transactions for the same phone, but allow a
        // retry if the previous transaction is expired or failed/cancelled.
        $existing = ORM::for_table('tbl_payment_gateway')
            ->where('username', $phone)
            ->where('gateway', 'mpesa')
            ->where('status', 1)
            ->find_one();
        if ($existing) {
            $isExpired = !empty($existing['expired_date']) && strtotime($existing['expired_date']) < time();
            if (!$isExpired) {
                r2(getUrl('mpesa_guest/wait/' . $existing['id']), 'w', Lang::T("An M-Pesa prompt is already active for this number — check your phone, or tap 'Send it again' on the next screen."));
            }
            // Try to resolve the stale transaction with Daraja; if it is still pending
            // we keep the existing one, otherwise we mark it and continue.
            $resolved = mpesa_resolve_pending_transaction($existing);
            if ($resolved === 'pending') {
                r2(getUrl('mpesa_guest/wait/' . $existing['id']), 'w', Lang::T("An M-Pesa prompt is already active for this number — check your phone, or tap 'Send it again' on the next screen."));
            }
            // Mark it as failed so the user can retry with a fresh STK push.
            $existing->status = 3;
            $existing->save();
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
        $d->expired_date = date('Y-m-d H:i:s', strtotime('+15 minutes'));
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

        // Validate gateway configuration and initiate STK push.
        mpesa_validate_config();
        mpesa_create_transaction($d, $guestUser, getUrl('mpesa_guest/init'));

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

        // Load the single-string voucher (username == password == code).
        $voucherMeta = ORM::for_table('tbl_meta')
            ->where('tbl', 'tbl_payment_gateway')
            ->where('tbl_id', $trx['id'])
            ->where('name', 'voucher')
            ->find_one();
        $voucher = $voucherMeta ? $voucherMeta['value'] : '';

        // Fallback for legacy guest rows created before the voucher flow.
        $user = ORM::for_table('tbl_customers')->where('username', $trx['username'])->find_one();
        $password = '';
        $username = $voucher;
        if (!$voucher && $user) {
            $meta = ORM::for_table('tbl_meta')
                ->where('tbl', 'tbl_customers')
                ->where('tbl_id', $user['id'])
                ->where('name', 'mpesa_password')
                ->find_one();
            if ($meta) {
                $password = $meta['value'];
                $username = $user['username'];
            }
        } elseif ($voucher) {
            $password = $voucher;
        }

        $context = ORM::for_table('tbl_meta')
            ->where('tbl', 'tbl_payment_gateway')
            ->where('tbl_id', $trx['id'])
            ->where('name', 'guest_context')
            ->find_one();

        $ctx = $context ? json_decode($context['value'], true) : [];
        $ui->assign('_title', Lang::T('Processing Payment'));
        $ui->assign('trx', $trx);
        $ui->assign('username', $username);
        $ui->assign('password', $password);
        $ui->assign('context', $ctx);
        $ui->assign('csrf_token', Csrf::generateAndStoreToken());
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

        require_once $PAYMENTGATEWAY_PATH . DIRECTORY_SEPARATOR . 'mpesa.php';

        $resolved = null;
        if ($trx['status'] == 1) {
            // Ask Daraja for the current status before telling the user to keep waiting.
            $resolved = mpesa_resolve_pending_transaction($trx);
            // Refresh the transaction object after resolve may have changed it.
            $trx = ORM::for_table('tbl_payment_gateway')->find_one($trxId);
            if (!$trx) {
                echo json_encode(['status' => 'error', 'message' => Lang::T('Transaction not found')]);
                exit;
            }

            // If Daraja could not be reached and the transaction has expired,
            // mark it as failed so the user can retry instead of waiting forever.
            if ($resolved === 'error' && !empty($trx['expired_date']) && strtotime($trx['expired_date']) < time()) {
                $trx->status = 3;
                $trx->save();
            }
        }

        if ($trx['status'] == 2) {
            // Already paid; ensure activation has run. For guests this returns
            // the single-string voucher ['username' => code, 'password' => code].
            $paid = mpesa_process_successful_payment($trx);

            // Guest flow always yields the voucher array; never expose a
            // registered customer's stored password on this public endpoint.
            $username = is_array($paid) ? ($paid['username'] ?? '') : '';
            $password = is_array($paid) ? ($paid['password'] ?? '') : '';

            $context = ORM::for_table('tbl_meta')
                ->where('tbl', 'tbl_payment_gateway')
                ->where('tbl_id', $trx['id'])
                ->where('name', 'guest_context')
                ->find_one();

            $ctx = $context ? json_decode($context['value'], true) : [];
            $dst = $ctx['dst'] ?? '';
            $linkLogin = $ctx['link_login'] ?? '';
            if ($linkLogin === '') {
                // Contexts stored before the portal-context fix carry no link
                // login; fall back so the Connect button still works.
                $linkLogin = $_SESSION['mpesa_guest_link_login'] ?? 'http://hotspot.rofatech.sovika.xyz/login';
            }

            echo json_encode([
                'status' => 'paid',
                'username' => $username,
                'password' => $password,
                'dst' => $dst,
                'link_login' => $linkLogin,
                'message' => Lang::T('Payment successful. You are being connected.'),
            ]);
            exit;
        } elseif ($trx['status'] == 3) {
            // Surface the real cause (STK timeout, wrong PIN, cancelled, etc.)
            // from the terminal Daraja verdict stored with the transaction.
            $cause = '';
            $detail = json_decode((string) ($trx['pg_paid_response'] ?? ''), true);
            if (is_array($detail)) {
                if (isset($detail['Body']['stkCallback']) && is_array($detail['Body']['stkCallback'])) {
                    $detail = $detail['Body']['stkCallback'];
                }
                $cause = trim((string) mpesa_stk_cause($detail));
            }
            $message = $cause !== ''
                ? $cause . ' ' . Lang::T('Please try again.')
                : Lang::T('Payment failed. Please try again.');
            echo json_encode(['status' => 'failed', 'cause' => $cause, 'message' => $message]);
            exit;
        } elseif ($trx['status'] == 4) {
            echo json_encode(['status' => 'cancelled', 'message' => Lang::T('Payment was cancelled.')]);
            exit;
        }

        echo json_encode(['status' => 'pending', 'message' => Lang::T('Waiting for M-Pesa confirmation...')]);
        exit;

    case 'resend':
        // Re-issue the STK prompt for an existing transaction whose original
        // prompt was closed or dismissed. Daraja has no API to re-display a
        // prompt, so a fresh STK push against the SAME row supersedes it —
        // without this, the duplicate-pending guard bounced guests to a wait
        // page for a prompt that no longer existed on their phone.
        $gatewayFile = $PAYMENTGATEWAY_PATH . DIRECTORY_SEPARATOR . 'mpesa.php';
        if (!file_exists($gatewayFile)) {
            _msglog('e', Lang::T('M-Pesa gateway not installed'));
            r2(getUrl('mpesa_guest/init'));
        }
        require_once $gatewayFile;

        $trxId = (int) $routes['2'];
        $trx = ORM::for_table('tbl_payment_gateway')->find_one($trxId);
        if (!$trx || $trx['gateway'] != 'mpesa') {
            _msglog('e', Lang::T('Transaction not found'));
            r2(getUrl('mpesa_guest/init'));
        }
        if (!Csrf::check(_post('csrf_token'))) {
            _msglog('e', Lang::T('Invalid or Expired CSRF Token'));
            r2(getUrl('mpesa_guest/wait/' . $trxId));
        }
        if ((int) $trx['status'] === 2) {
            r2(getUrl('mpesa_guest/wait/' . $trxId), 's', Lang::T('This payment has already been received.'));
        }

        // Last chance check: the original prompt may have completed after all.
        if ((int) $trx['status'] === 1) {
            mpesa_resolve_pending_transaction($trx);
            $trx = ORM::for_table('tbl_payment_gateway')->find_one($trxId);
            if ($trx && (int) $trx['status'] === 2) {
                r2(getUrl('mpesa_guest/wait/' . $trxId), 's', Lang::T('This payment has already been received.'));
            }
        }
        // Re-open a row the poll already marked failed, then push again.
        if ($trx && (int) $trx['status'] === 3) {
            $trx->status = 1;
            $trx->save();
        }

        $guestUser = ['id' => 0, 'username' => $trx['username'], 'phonenumber' => $trx['username']];
        mpesa_create_transaction($trx, $guestUser, getUrl('mpesa_guest/wait/' . $trxId));
        r2(getUrl('mpesa_guest/wait/' . $trxId), 's', Lang::T('A new M-Pesa prompt has been sent — check your phone.'));
        break;

    case 'retrieve':
        // Self-resolution: enter the phone number used to pay, re-confirm the
        // transaction with Daraja, and show (or generate) the voucher.
        $gatewayFile = $PAYMENTGATEWAY_PATH . DIRECTORY_SEPARATOR . 'mpesa.php';
        if (!file_exists($gatewayFile)) {
            _msglog('e', Lang::T('M-Pesa gateway not installed'));
            r2(getUrl('mpesa_guest/init'));
        }
        require_once $gatewayFile;

        $found = false;
        $username = '';
        $password = '';
        $ctx = [];

        if ($_SERVER['REQUEST_METHOD'] === 'POST') {
            if (!Csrf::check(_post('csrf_token'))) {
                _msglog('e', Lang::T('Invalid or Expired CSRF Token'));
                r2(getUrl('mpesa_guest/retrieve'));
            }
            $phone = mpesa_normalize_phone(_post('phone'));
            if (!$phone) {
                _msglog('e', Lang::T('Please enter a valid phone number'));
                r2(getUrl('mpesa_guest/retrieve'));
            }

            $trx = ORM::for_table('tbl_payment_gateway')
                ->where('username', $phone)
                ->where('gateway', 'mpesa')
                ->order_by_desc('id')
                ->find_one();
            if (!$trx) {
                _msglog('e', Lang::T('No payment found for this phone number'));
                r2(getUrl('mpesa_guest/retrieve'));
            }

            // Authoritative re-check: Daraja decides, for both rows still
            // pending AND rows marked failed (a premature fail must not tell a
            // paying guest "no transaction" — this was the reported bug).
            if ($trx && in_array((int) $trx['status'], [1, 3], true)) {
                mpesa_resolve_pending_transaction($trx);
                $trx = ORM::for_table('tbl_payment_gateway')->find_one($trx['id']);
            }

            // Fallback: if the newest row for this phone is still not paid
            // (e.g. a failed retry tap sitting on top of a successful payment),
            // surface the most recent PAID transaction instead.
            if ($trx && (int) $trx['status'] !== 2) {
                $paidTrx = ORM::for_table('tbl_payment_gateway')
                    ->where('username', $phone)
                    ->where('gateway', 'mpesa')
                    ->where('status', 2)
                    ->whereRaw('created_date >= ' . "'" . date('Y-m-d H:i:s', time() - 7200) . "'")
                    ->order_by_desc('id')
                    ->find_one();
                if ($paidTrx) {
                    $trx = $paidTrx;
                }
            }

            if ($trx && $trx['status'] == 2) {
                // Paid: ensure the voucher exists (generates it if missing) and
                // returns ['username' => code, 'password' => code].
                $paid = mpesa_process_successful_payment($trx);
                if (is_array($paid)) {
                    $username = $paid['username'] ?? '';
                    $password = $paid['password'] ?? '';
                    $found = ($username !== '' && $password !== '');
                }
                if (!$found) {
                    _msglog('e', Lang::T('Payment found but voucher could not be generated. Please contact support.'));
                    r2(getUrl('mpesa_guest/retrieve'));
                }

                $gctx = ORM::for_table('tbl_meta')
                    ->where('tbl', 'tbl_payment_gateway')
                    ->where('tbl_id', $trx['id'])
                    ->where('name', 'guest_context')
                    ->find_one();
                $ctx = $gctx ? json_decode($gctx['value'], true) : [];
            } elseif ($trx && $trx['status'] == 1) {
                _msglog('w', Lang::T('M-Pesa is still confirming your payment — please try again in a few seconds.'));
                r2(getUrl('mpesa_guest/retrieve'));
            } else {
                // Genuinely failed: show WHY (timeout / cancelled / wrong PIN).
                $cause = '';
                $detail = json_decode((string) ($trx['pg_paid_response'] ?? ''), true);
                if (is_array($detail)) {
                    if (isset($detail['Body']['stkCallback']) && is_array($detail['Body']['stkCallback'])) {
                        $detail = $detail['Body']['stkCallback'];
                    }
                    $cause = trim((string) mpesa_stk_cause($detail));
                }
                _msglog('e', $cause !== ''
                    ? $cause . ' ' . Lang::T('Please try again.')
                    : Lang::T('Payment failed. Please try again.'));
                r2(getUrl('mpesa_guest/retrieve'));
            }
        }

        // Where the guest can paste the voucher (MikroTik portal login page).
        // Fallback covers transactions stored before the context-wipe fix.
        $loginUrl = $ctx['link_login'] ?? '';
        if ($loginUrl === '') {
            $loginUrl = $_SESSION['mpesa_guest_link_login'] ?? '';
        }
        if ($loginUrl === '') {
            $loginUrl = 'http://hotspot.rofatech.sovika.xyz/login';
        }

        $ui->assign('_title', Lang::T('Retrieve Your Voucher'));
        $ui->assign('found', $found);
        $ui->assign('username', $username);
        $ui->assign('password', $password);
        $ui->assign('context', $ctx);
        $ui->assign('login_url', $loginUrl);
        $ui->assign('csrf_token', Csrf::generateAndStoreToken());
        $ui->display('customer/mpesa_guest_retrieve.tpl');
        break;

    case 'status':
        // Public session-countdown page (post-login landing) identified by the
        // single-string voucher code: time remaining + data remaining.
        $code = Text::alphanumeric($routes['2'] ?? '', '-_.,');

        $st = [
            'active' => false,
            'connected' => false,
            'session_start' => 0,
            'plan_name' => '',
            'time_left' => 0,
            'expires_at' => 0,
            'has_data_limit' => false,
            'data_limit' => 0,
            'data_used' => 0,
            'data_left' => 0,
        ];

        if ($code !== '') {
            $tur = ORM::for_table('tbl_user_recharges')
                ->where('username', $code)
                ->where('status', 'on')
                ->order_by_desc('id')
                ->find_one();
            if ($tur) {
                $st['active'] = true;
                $st['plan_name'] = $tur['namebp'];
                $expiresAt = strtotime($tur['expiration'] . ' ' . $tur['time']);
                $st['expires_at'] = $expiresAt;

                $plan = ORM::for_table('tbl_plans')->find_one($tur['plan_id']);
                $sessionCap = null;
                if ($plan) {
                    // Total data used for this username across sessions.
                    $used = 0;
                    foreach (ORM::for_table('rad_acct')->where('username', $code)->find_array() as $row) {
                        $used += intval($row['acctoutputoctets']) + intval($row['acctinputoctets']);
                    }
                    $st['data_used'] = $used;
                    if (
                        $plan['typebp'] == 'Limited'
                        && ($plan['limit_type'] == 'Data_Limit' || $plan['limit_type'] == 'Both_Limit')
                        && intval($plan['data_limit']) > 0
                    ) {
                        $limitBytes = Text::convertDataUnit($plan['data_limit'], $plan['data_unit']);
                        $st['has_data_limit'] = true;
                        $st['data_limit'] = $limitBytes;
                        $st['data_left'] = max(0, $limitBytes - $used);
                    }
                    if (
                        $plan['typebp'] == 'Limited'
                        && ($plan['limit_type'] == 'Time_Limit' || $plan['limit_type'] == 'Both_Limit')
                        && intval($plan['time_limit']) > 0
                    ) {
                        $sessionCap = intval($plan['time_limit']) * (($plan['time_unit'] == 'Hrs') ? 3600 : 60);
                    }
                }

                // The countdown must start when the ROUTER session starts
                // (accounting Start), not when the package was purchased —
                // before Connect there is no session, so nothing ticks down.
                $sess = ORM::for_table('rad_acct')
                    ->where('username', $code)
                    ->order_by_desc('dateAdded')
                    ->find_one();
                $sessionStart = 0;
                if ($sess) {
                    $sessStatus = (string) $sess['acctstatustype'];
                    if ($sessStatus === 'Start' || $sessStatus === 'Interim-Update') {
                        $sessionStart = strtotime($sess['dateAdded']);
                    } elseif ($sessStatus === 'Stop' && intval($sess['acctsessiontime']) === 0) {
                        // frrest_interim_update marks rows Stop after a minute
                        // of accounting silence even while the NAS session is
                        // still live (no Interim-Update configured) — treat a
                        // zero-sessiontime Stop as connected inside the cap
                        // window; a real NAS Stop always carries sessiontime > 0.
                        $window = ($sessionCap ?: 3600) + 120;
                        if (time() - strtotime($sess['dateAdded']) < $window) {
                            $sessionStart = strtotime($sess['dateAdded']);
                        }
                    }
                }

                $st['connected'] = $sessionStart > 0;
                $st['session_start'] = $sessionStart;
                if ($st['connected']) {
                    $remaining = ($sessionCap !== null)
                        ? min($sessionCap - (time() - $sessionStart), max(0, $expiresAt - time()))
                        : max(0, $expiresAt - time());
                    $st['time_left'] = max(0, $remaining);
                } else {
                    $st['time_left'] = 0;
                }
            }
        }

        // Refresh endpoint (ajax): return JSON so the page updates in place.
        if (_get('refresh')) {
            header('Content-Type: application/json');
            echo json_encode($st);
            exit;
        }
        $ui->assign('_title', Lang::T('Session Status'));
        $ui->assign('code', $code);
        $ui->assign('st', $st);
        $ui->assign('continue_url', _get('dst'));
        $ui->display('customer/mpesa_guest_status.tpl');
        break;

    default:
        r2(getUrl('mpesa_guest/init'));
}
