{include file="customer/header-public.tpl"}
<div class="hidden-xs" style="height:50px"></div>
<div class="row">
    <div class="col-sm-6 col-sm-offset-3">
        <div class="panel panel-primary" id="waitingPanel">
            <div class="panel-heading">{Lang::T('Processing Payment')}</div>
            <div class="panel-body text-center">
                <p>{Lang::T('Please check your phone and enter your M-Pesa PIN to complete the payment.')}</p>
                <div class="progress">
                    <div class="progress-bar progress-bar-striped active" role="progressbar" style="width: 100%"></div>
                </div>
                <p id="statusText">{Lang::T('Waiting for M-Pesa confirmation...')}</p>
            </div>
        </div>

        <div class="panel panel-success hidden" id="successPanel">
            <div class="panel-heading">{Lang::T('Payment Successful')}</div>
            <div class="panel-body text-center">
                <p>{Lang::T('Your payment has been received and your device is being connected.')}</p>
                <div id="credentialsBox" class="alert alert-info hidden">
                    <p><strong>{Lang::T('Username')}:</strong> <span id="usernameText"></span></p>
                    <p><strong>{Lang::T('Password')}:</strong> <span id="passwordText"></span></p>
                    <button type="button" class="btn btn-primary btn-sm" id="copyBtn">{Lang::T('Copy to Clipboard')}</button>
                </div>
                <a id="continueBtn" href="#" class="btn btn-success btn-lg">{Lang::T('Continue to Internet')}</a>
            </div>
        </div>

        <div class="panel panel-danger hidden" id="failedPanel">
            <div class="panel-heading">{Lang::T('Payment Failed')}</div>
            <div class="panel-body text-center">
                <p id="failedText"></p>
                <a href="{Text::url('mpesa_guest/init')}" class="btn btn-primary">{Lang::T('Try Again')}</a>
            </div>
        </div>
    </div>
</div>

<script>
(function () {
    const trxId = {$trx.id};
    const checkUrl = '{Text::url('mpesa_guest/check/')}' + trxId;
    const originalDst = '{$context.dst|escape:'javascript'}';

    function checkStatus() {
        fetch(checkUrl)
            .then(r => r.json())
            .then(data => {
                if (data.status === 'paid') {
                    document.getElementById('waitingPanel').classList.add('hidden');
                    document.getElementById('successPanel').classList.remove('hidden');
                    if (data.username && data.password) {
                        document.getElementById('usernameText').textContent = data.username;
                        document.getElementById('passwordText').textContent = data.password;
                        document.getElementById('credentialsBox').classList.remove('hidden');

                        const continueBtn = document.getElementById('continueBtn');
                        if (originalDst) {
                            continueBtn.href = originalDst;
                        } else {
                            continueBtn.classList.add('hidden');
                        }

                        document.getElementById('copyBtn').addEventListener('click', function () {
                            navigator.clipboard.writeText('Username: ' + data.username + '\nPassword: ' + data.password)
                                .then(() => alert('{Lang::T('Credentials copied')}'))
                                .catch(() => alert('{Lang::T('Could not copy credentials')}'));
                        });
                    }
                } else if (data.status === 'failed' || data.status === 'cancelled') {
                    document.getElementById('waitingPanel').classList.add('hidden');
                    document.getElementById('failedPanel').classList.remove('hidden');
                    document.getElementById('failedText').textContent = data.message || '{Lang::T('Payment could not be completed')}';
                } else {
                    document.getElementById('statusText').textContent = data.message || '{Lang::T('Waiting for M-Pesa confirmation...')}';
                    setTimeout(checkStatus, 5000);
                }
            })
            .catch(() => {
                setTimeout(checkStatus, 8000);
            });
    }

    setTimeout(checkStatus, 3000);
})();
</script>
{include file="customer/footer-public.tpl"}
