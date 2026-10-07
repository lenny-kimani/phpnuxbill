<?php

/**
 * M-Pesa Payment Gateway loader
 *
 * This file is part of the main PHPNuxBill repository. The actual gateway
 * implementation lives in system/paymentgateway/mpesa/ and is intended to be
 * maintained as a separate git submodule.
 */

global $ui, $PAYMENTGATEWAY_PATH;

// Register the submodule's UI directory with Smarty so mpesa.tpl is found.
if (isset($ui) && $ui instanceof Smarty) {
    $ui->addTemplateDir($PAYMENTGATEWAY_PATH . '/mpesa/ui/', 'mpesa_pg');
}

// Load the real gateway implementation from the submodule.
$gatewayFile = $PAYMENTGATEWAY_PATH . DIRECTORY_SEPARATOR . 'mpesa' . DIRECTORY_SEPARATOR . 'mpesa.php';
if (file_exists($gatewayFile)) {
    require_once $gatewayFile;
} else {
    die('M-Pesa gateway submodule not found at system/paymentgateway/mpesa/');
}
