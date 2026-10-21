<?php

class RadiusRest {

    // show Description
    function description()
    {
        return [
            'title' => 'Radius Rest API',
            'description' => 'This devices will handle Radius Connection using Rest API',
            'author' => 'ibnu maksum',
            'url' => [
                'Wiki Tutorial' => 'https://github.com/hotspotbilling/phpnuxbill/wiki/FreeRadius-Rest',
                'Telegram' => 'https://t.me/phpnuxbill',
                'Donate' => 'https://paypal.me/ibnux'
            ]
        ];
    }

    // Add Customer to Mikrotik/Device
    function add_customer($customer, $plan)
    {
    }
	
	function sync_customer($customer, $plan)
    {	
        $this->add_customer($customer, $plan);
    }

    // Remove Customer to Mikrotik/Device
    function remove_customer($customer, $plan)
    {
        // set zero data usage
        if ($plan['typebp'] == "Limited" && ($plan['limit_type'] == "Data_Limit" || $plan['limit_type'] == "Both_Limit")) {
            $cs = ORM::for_table("rad_acct")->where('username', $customer['username'])->findMany();
            foreach ($cs as $c) {
                $c->acctOutputOctets = 0;
                $c->acctInputOctets = 0;
                $c->save();
            }
        }
    }

    // customer change username
    public function change_username($plan, $from, $to)
    {
    }

    // Add Plan to Mikrotik/Device
    function add_plan($plan)
    {
    }

    // Update Plan to Mikrotik/Device
    function update_plan($old_name, $plan)
    {
    }

    // Remove Plan from Mikrotik/Device
    function remove_plan($plan)
    {
    }

    // check if customer is online
    function online_customer($customer, $router_name)
    {
    }

    /**
     * Send a RADIUS Disconnect-Request (PoD) to the NAS holding this user's
     * active session, then mark the local accounting row stopped so the
     * shared-users / Simultaneous-Use slot frees up for the next login.
     *
     * @param string $username
     */
    private function radiusKick($username)
    {
        global $_app_stage;
        if ($_app_stage == 'Demo' || empty($username)) {
            return;
        }

        $act = ORM::for_table('rad_acct')
            ->where('username', $username)
            ->where('acctstatustype', 'Start')
            ->find_one();
        if (!$act) {
            return;
        }

        $nasIp = trim((string)$act['nasipaddress']);
        $framedIp = trim((string)$act['framedipaddress']);
        $port = 3799;
        $secret = '';

        $nas = ORM::for_table('nas')->where('nasname', $nasIp)->find_one();
        if ($nas) {
            if (!empty($nas['secret'])) {
                $secret = (string)$nas['secret'];
            }
            if (!empty($nas['ports'])) {
                $port = (int)$nas['ports'];
            }
        }
        if ($secret === '') {
            $secret = (string)(getenv('RADIUS_SECRET') ?: '');
        }

        if ($nasIp === '' || $secret === '') {
            _log('RadiusRest: cannot disconnect ' . $username . ' - missing NAS IP or RADIUS secret');
            return;
        }

        $payload = "User-Name = \"$username\"\nFramed-IP-Address = \"$framedIp\"\n";
        $cmd = 'echo ' . escapeshellarg($payload)
            . ' | radclient -x ' . escapeshellarg($nasIp . ':' . $port)
            . ' disconnect ' . escapeshellarg($secret) . ' 2>&1';
        $output = @shell_exec($cmd);

        $act->acctstatustype = 'Stop';
        $act->save();

        _log('RadiusRest: disconnect ' . $username . ' @ ' . $nasIp . ':' . $port . ' -> ' . trim((string)$output));
    }

    // make customer online
    // RADIUS sessions are always initiated by the NAS, so nothing can be pushed
    // server-side. We clear any stale session (freeing the Simultaneous-Use /
    // shared_users slot) and the real login happens client-side when the guest's
    // browser is redirected to link_login with the voucher credentials.
    function connect_customer($customer, $ip, $mac_address, $router_name)
    {
        $this->radiusKick($customer['username']);
    }

    // make customer disconnect
    function disconnect_customer($customer, $router_name)
    {
        $this->radiusKick($customer['username']);
    }

}