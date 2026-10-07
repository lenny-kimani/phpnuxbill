{include file="customer/header-public.tpl"}
<style>
  @keyframes gradientShift {
    0%   { background-position: 0% 50%; }
    50%  { background-position: 100% 50%; }
    100% { background-position: 0% 50%; }
  }
  @keyframes spin {
    0%   { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
  }
  @keyframes pulse {
    0%,100% { opacity:1; transform:scale(1); }
    50%      { opacity:0.4; transform:scale(0.85); }
  }
  body, #app {
    background: linear-gradient(135deg, #1a1a2e, #16213e, #0f3460, #533483, #e94560, #0f3460, #16213e) !important;
    background-size: 400% 400% !important;
    animation: gradientShift 18s ease infinite !important;
    min-height: 100vh;
    color: #f0f0f0;
  }
  .rofa-header { text-align: center; padding: 20px 16px 8px; }
  .rofa-header h2 { font-size: 1.6rem; font-weight: 700; color: #fff; text-shadow: 0 2px 8px rgba(0,0,0,0.4); margin: 0 0 2px; }
  .rofa-header .tagline { font-size: 0.78rem; color: rgba(255,255,255,0.6); letter-spacing: 3px; text-transform: uppercase; }
  .rofa-page { max-width: 520px; margin: 0 auto; padding: 0 14px 30px; }
  .status-card {
    background: rgba(255,255,255,0.08);
    border: 1px solid rgba(255,255,255,0.14);
    border-radius: 14px;
    backdrop-filter: blur(6px);
    -webkit-backdrop-filter: blur(6px);
    box-shadow: 0 4px 18px rgba(0,0,0,0.3);
    margin-bottom: 16px;
    overflow: hidden;
  }
  .status-card-header {
    padding: 14px 18px;
    border-bottom: 1px solid rgba(255,255,255,0.1);
    font-weight: 700;
    font-size: 1rem;
    color: #fff;
  }
  .status-card-body { padding: 22px 18px; text-align: center; }
  .spinner {
    width: 52px; height: 52px;
    border: 5px solid rgba(255,255,255,0.12);
    border-top-color: #69f0ae;
    border-radius: 50%;
    animation: spin 0.9s linear infinite;
    margin: 0 auto 16px;
  }
  .status-text { font-size: 0.95rem; color: rgba(255,255,255,0.75); margin-bottom: 6px; }
  .status-subtext { font-size: 0.82rem; color: rgba(255,255,255,0.45); }
  .success-icon { font-size: 3rem; margin-bottom: 10px; }
  .failed-icon { font-size: 3rem; margin-bottom: 10px; }
  .cred-box {
    background: rgba(105,240,174,0.1);
    border: 1px solid rgba(105,240,174,0.3);
    border-radius: 10px;
    padding: 14px 16px;
    margin: 16px 0;
    text-align: left;
  }
  .cred-row { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; font-size: 0.92rem; }
  .cred-row:last-child { margin-bottom: 0; }
  .cred-label { color: rgba(255,255,255,0.55); }
  .cred-value { color: #fff; font-weight: 700; font-family: monospace; letter-spacing: 0.5px; }
  .btn-action {
    display: block; width: 100%; padding: 13px;
    border-radius: 8px; border: none;
    font-size: 1rem; font-weight: 700; cursor: pointer;
    text-align: center; text-decoration: none;
    margin-bottom: 10px; transition: transform 0.15s;
    box-sizing: border-box;
  }
  .btn-action:hover { transform: translateY(-1px); text-decoration: none; }
  .btn-continue { background: linear-gradient(135deg, #43a047, #1b5e20); color: #fff; }
  .btn-copy { background: rgba(105,240,174,0.15); border: 1px solid rgba(105,240,174,0.35); color: #69f0ae; }
  .btn-retry { background: linear-gradient(135deg, #533483, #0f3460); color: #fff; }
  .btn-tryagain { background: linear-gradient(135deg, #e94560, #c62a47); color: #fff; }
  .retry-hint { font-size: 0.78rem; color: rgba(255,255,255,0.45); text-align: center; margin-top: 4px; }
  .hidden { display: none !important; }
  .rofa-footer { text-align: center; font-size: 0.75rem; color: rgba(255,255,255,0.35); padding-bottom: 10px; }
  .rofa-footer a { color: rgba(255,255,255,0.45); text-decoration: none; }
  .rofa-footer a:hover { color: #fff; }
</style>

<div class="rofa-header">
  <h2>&#x1F4F6; Rofatech Hotspot</h2>
  <p class="tagline">Wireless Internet</p>
</div>

<div class="rofa-page">

  <!-- WAITING PANEL -->
  <div class="status-card" id="waitingPanel">
    <div class="status-card-header">&#x23F3; {Lang::T('Processing Payment')}</div>
    <div class="status-card-body">
      <div class="spinner"></div>
      <p class="status-text">{Lang::T('Please check your phone and enter your M-Pesa PIN.')}</p>
      <p class="status-subtext" id="statusText">{Lang::T('Waiting for M-Pesa confirmation...')}</p>
    </div>
  </div>

  <!-- SUCCESS PANEL -->
  <div class="status-card hidden" id="successPanel">
    <div class="status-card-header" style="background:rgba(67,160,71,0.2);">&#x2705; {Lang::T('Payment Successful')}</div>
    <div class="status-card-body">
      <div class="success-icon">&#x1F389;</div>
      <p class="status-text">{Lang::T('Your payment has been received.')}</p>
      <p class="status-subtext" id="autoAuthMsg">{Lang::T('Connecting your device automatically...')}</p>

      <div id="credentialsBox" class="cred-box hidden">
        <div class="cred-row">
          <span class="cred-label">{Lang::T('Username')}</span>
          <span class="cred-value" id="usernameText"></span>
        </div>
        <div class="cred-row">
          <span class="cred-label">{Lang::T('Password')}</span>
          <span class="cred-value" id="passwordText"></span>
        </div>
      </div>

      <a id="continueBtn" href="#" class="btn-action btn-continue hidden">&#x1F310; {Lang::T('Continue to Internet')}</a>
      <button type="button" class="btn-action btn-copy hidden" id="copyBtn">&#x1F4CB; {Lang::T('Copy Credentials')}</button>
      <button type="button" class="btn-action btn-retry hidden" id="retryBtn">&#x1F504; {Lang::T('Retry Connection')}</button>
      <p class="retry-hint hidden" id="retryHint">{Lang::T('If auto-connect did not work, tap Retry or use the credentials above to login manually.')}</p>
    </div>
  </div>

  <!-- FAILED PANEL -->
  <div class="status-card hidden" id="failedPanel">
    <div class="status-card-header" style="background:rgba(233,69,96,0.2);">&#x274C; {Lang::T('Payment Failed')}</div>
    <div class="status-card-body">
      <div class="failed-icon">&#x1F625;</div>
      <p class="status-text" id="failedText">{Lang::T('Payment could not be completed.')}</p>
      <a href="{Text::url('mpesa_guest/init')}" class="btn-action btn-tryagain">&#x21BA; {Lang::T('Try Again')}</a>
    </div>
  </div>

  <div class="rofa-footer">
    <a href="{APP_URL}/pages/Privacy_Policy.html" target="_blank">Privacy</a>
    &nbsp;&bull;&nbsp;
    <a href="{APP_URL}/pages/Terms_of_Conditions.html" target="_blank">Terms</a>
    &nbsp;&bull;&nbsp;
    &copy; Rofatech
  </div>
</div>

<script>
(function () {
    var trxId = {$trx.id};
    var checkUrl = '{Text::url('mpesa_guest/check/')}' + trxId;
    var originalDst = '{$context.dst|escape:'javascript'}';
    var retryCount = 0;

    function showSuccess(data) {
        document.getElementById('waitingPanel').classList.add('hidden');
        document.getElementById('successPanel').classList.remove('hidden');

        if (data.username && data.password) {
            document.getElementById('usernameText').textContent = data.username;
            document.getElementById('passwordText').textContent = data.password;
            document.getElementById('credentialsBox').classList.remove('hidden');
            document.getElementById('copyBtn').classList.remove('hidden');

            document.getElementById('copyBtn').addEventListener('click', function () {
                var text = 'Username: ' + data.username + '\nPassword: ' + data.password;
                if (navigator.clipboard) {
                    navigator.clipboard.writeText(text)
                        .then(function() { alert('{Lang::T('Credentials copied')}'); })
                        .catch(function() { alert(text); });
                } else {
                    alert(text);
                }
            });
        }

        if (originalDst) {
            var continueBtn = document.getElementById('continueBtn');
            continueBtn.href = originalDst;
            continueBtn.classList.remove('hidden');
            document.getElementById('autoAuthMsg').textContent = '{Lang::T('Redirecting you to the internet...')}';
            setTimeout(function() { window.location.href = originalDst; }, 3000);
        } else {
            document.getElementById('autoAuthMsg').textContent = '{Lang::T('Your device should now be connected.')}';
            document.getElementById('retryBtn').classList.remove('hidden');
            document.getElementById('retryHint').classList.remove('hidden');
        }
    }

    function checkStatus() {
        fetch(checkUrl)
            .then(function(r) { return r.json(); })
            .then(function(data) {
                if (data.status === 'paid') {
                    showSuccess(data);
                } else if (data.status === 'failed' || data.status === 'cancelled') {
                    document.getElementById('waitingPanel').classList.add('hidden');
                    document.getElementById('failedPanel').classList.remove('hidden');
                    document.getElementById('failedText').textContent = data.message || '{Lang::T('Payment could not be completed')}';
                } else {
                    document.getElementById('statusText').textContent = data.message || '{Lang::T('Waiting for M-Pesa confirmation...')}';
                    retryCount++;
                    var delay = retryCount < 6 ? 5000 : 10000;
                    setTimeout(checkStatus, delay);
                }
            })
            .catch(function() {
                setTimeout(checkStatus, 8000);
            });
    }

    document.getElementById('retryBtn').addEventListener('click', function() {
        if (originalDst) {
            window.location.href = originalDst;
        } else {
            document.getElementById('autoAuthMsg').textContent = '{Lang::T('Retrying connection...')}';
            fetch(checkUrl)
                .then(function(r) { return r.json(); })
                .then(function(data) {
                    if (data.status === 'paid') {
                        document.getElementById('autoAuthMsg').textContent = '{Lang::T('Reconnect request sent.')}';
                    }
                });
        }
    });

    setTimeout(checkStatus, 3000);
})();
</script>
{include file="customer/footer-public.tpl"}
