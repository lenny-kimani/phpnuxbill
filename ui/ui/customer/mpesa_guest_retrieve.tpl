{include file="customer/header-public.tpl"}
<style>
  .rv-code {
    background: rgba(105,240,174,0.10);
    border: 1px solid rgba(105,240,174,0.35);
    border-radius: 10px;
    padding: 18px 16px;
    margin: 14px 0;
    font-size: 2rem;
    font-weight: 800;
    font-family: 'Courier New', monospace;
    letter-spacing: 3px;
    color: #69f0ae;
    text-align: center;
    user-select: all;
    -webkit-user-select: all;
  }
</style>

<div class="rofa-page">
  <p class="rofa-hint" style="text-align:center; margin-bottom:16px; font-size:1.05rem; color:rgba(255,255,255,0.85);">
    {Lang::T('Already paid? Retrieve your voucher')}
  </p>

  {if $found}
    <div class="rofa-card">
      <div class="rofa-card-body" style="text-align:center;">
        <div style="font-size:2.4rem; margin-bottom:6px;">&#x2705;</div>
        <p style="font-size:1rem; color:#fff; font-weight:700; margin:0 0 4px;">
          {Lang::T('Payment confirmed')}
        </p>
        <p class="rofa-hint">{Lang::T('Your voucher — paste it on the login page')}</p>

        <div class="rv-code" id="rvCode">{$username}</div>

        <button type="button" class="rofa-btn" id="copyBtn"
                style="width:100%; margin-bottom:10px; background:rgba(105,240,174,0.15); color:#69f0ae; border:1px solid rgba(105,240,174,0.35);">
          &#x1F4CB; {Lang::T('Copy voucher')}
        </button>

        {if $login_url}
          <a href="{$login_url|escape:'html'}" class="rofa-btn rofa-btn-primary" style="width:100%; margin-bottom:10px;">
            &#x1F510; {Lang::T('Go to login page')}
          </a>
        {/if}

        <p class="rofa-hint">
          {Lang::T('On the login page, paste the voucher into the voucher field and tap Connect.')}
        </p>
        <div style="text-align:center; margin-top:10px;">
          <a href="{Text::url('mpesa_guest/init')}" class="rofa-hint">&larr; {Lang::T('Back to packages')}</a>
        </div>
      </div>
    </div>
  {else}
    <div class="rofa-card">
      <div class="rofa-card-body">
        <form action="{Text::url('mpesa_guest/retrieve')}" method="post">
          <input type="hidden" name="csrf_token" value="{$csrf_token}">
          <label class="rofa-label">{Lang::T('M-Pesa Phone Number')}</label>
          <input type="tel" class="rofa-input" name="phone" required
            placeholder="e.g. 0712345678 or 254712345678"
            pattern="{literal}^\+?(?:254|0)?[17][0-9]{8}${/literal}"
            autocomplete="tel"
            style="background:#ffffff; color:#000000; -webkit-text-fill-color:#000000; caret-color:#000000;" />
          <button type="submit" class="rofa-btn rofa-btn-primary" style="width:100%;">
            {Lang::T('Find my payment')}
          </button>
          <p class="rofa-hint">{Lang::T('Enter the phone number you paid with to get your voucher')}</p>
        </form>
        <div style="text-align:center; margin-top:10px;">
          <a href="{Text::url('mpesa_guest/init')}" class="rofa-hint">&larr; {Lang::T('Back to packages')}</a>
        </div>
      </div>
    </div>
  {/if}

  <div class="rofa-footer">
    <a href="{APP_URL}/pages/Privacy_Policy.html" target="_blank">Privacy</a>
    &nbsp;&bull;&nbsp;
    <a href="{APP_URL}/pages/Terms_of_Conditions.html" target="_blank">Terms</a>
  </div>
</div>

{if $found}
<script>
(function () {
    var code = '{$username|escape:'javascript'}';
    document.getElementById('copyBtn').addEventListener('click', function () {
        if (navigator.clipboard) {
            navigator.clipboard.writeText(code)
                .then(function () { alert('{Lang::T('Voucher copied')}'); })
                .catch(function () { alert(code); });
        } else {
            alert(code);
        }
    });
})();
</script>
{/if}
{include file="customer/footer-public.tpl"}
