{include file="customer/header-public.tpl"}

<div class="rofa-page">
  <p class="rofa-hint" style="text-align:center; margin-bottom:18px; font-size:1.05rem; color:rgba(255,255,255,0.85);">
    {Lang::T('Fast and reliable internet')}
  </p>
  {if count($plans) > 0}
    <div class="rofa-package-list">
      {foreach $plans as $p}
      <div class="rofa-package-row" id="row-{$p.id}">
        <div style="flex:1; min-width:0;">
          <div class="pkg-name">{$p.name_plan}</div>
          <div class="pkg-meta">
            {if $p.validity > 0}{$p.validity} {$p.validity_unit}{/if}
            {if $p.validity > 0 && $p.typebp != ''}&nbsp;&bull;&nbsp;{/if}
            {if $p.typebp == 'Unlimited'}
              {Lang::T('Unlimited')}
            {elseif $p.limit_type == 'Time_Limit' && $p.time_limit > 0}
              {$p.time_limit} {$p.time_unit} {Lang::T('limit')}
            {elseif $p.limit_type == 'Data_Limit' && $p.data_limit > 0}
              {$p.data_limit} {$p.data_unit} {Lang::T('limit')}
            {elseif $p.limit_type == 'Both_Limit'}
              {Lang::T('Limited')}
            {/if}
          </div>
        </div>
        <div class="pkg-price">{Lang::moneyFormat($p.price)}</div>
        <button type="button" class="rofa-btn rofa-btn-success pkg-buy" onclick="selectPlan({$p.id})">
          {Lang::T('Buy')}
        </button>
      </div>

      <div class="rofa-card" id="form-{$p.id}" style="display:none; margin-top:-6px; margin-bottom:14px;">
        <div class="rofa-card-body">
          <form action="{Text::url('mpesa_guest/pay')}" method="post">
            <input type="hidden" name="csrf_token" value="{$csrf_token}">
            <input type="hidden" name="mac" value="{$mac}">
            <input type="hidden" name="ip" value="{$ip}">
            <input type="hidden" name="router" value="{$router}">
            <input type="hidden" name="plan" value="{$p.id}">

            <label class="rofa-label">{Lang::T('M-Pesa Phone Number')}</label>
            <input type="tel" class="rofa-input" name="phone" required
              placeholder="e.g. 0712345678 or 254712345678"
              pattern="{literal}^\+?(?:254|0)?[17][0-9]{8}${/literal}"
              autocomplete="tel"
              style="background:#ffffff; color:#000000; -webkit-text-fill-color:#000000; caret-color:#000000;" />
            <button type="submit" class="rofa-btn rofa-btn-primary">
              {Lang::T('Pay with M-Pesa')}
            </button>
            <p class="rofa-hint">{Lang::T('You will receive an STK push on your phone')}</p>
          </form>
        </div>
      </div>
      {/foreach}
    </div>
  {else}
    <div class="rofa-card">
      <div class="rofa-card-body" style="text-align:center;">
        <p style="font-size:1rem; color:rgba(255,255,255,0.8); margin:0;">
          {Lang::T('No plans available for this location')}
        </p>
        <p class="rofa-hint" style="margin-top:6px;">
          {Lang::T('Please contact support for assistance')}
        </p>
      </div>
    </div>
  {/if}

  <div class="rofa-contact">
    {Lang::T('Need help? Contact support')}
  </div>

  <div style="text-align:center; margin:14px 0;">
    <a href="{Text::url('mpesa_guest/retrieve')}" class="rofa-sovika">
      &#x1F50D; {Lang::T('Click here if you have the mpesa message but did not get an automatic voucher')}
    </a>
  </div>

  <div style="text-align:center; margin:16px 0;">
    <a href="https://sovika.xyz" target="_blank" rel="noopener noreferrer" class="rofa-sovika">
      &#x1F680; {Lang::T('Powered by Sovika Technologies')}
    </a>
  </div>

  <div class="rofa-footer">
    <a href="{APP_URL}/pages/Privacy_Policy.html" target="_blank">Privacy</a>
    &nbsp;&bull;&nbsp;
    <a href="{APP_URL}/pages/Terms_of_Conditions.html" target="_blank">Terms</a>
  </div>
</div>

<script>
  function selectPlan(id) {
    var allForms = document.querySelectorAll('[id^="form-"]');
    for (var i = 0; i < allForms.length; i++) allForms[i].style.display = 'none';
    document.getElementById('form-' + id).style.display = 'block';
    var input = document.getElementById('form-' + id).querySelector('input[type="tel"]');
    if (input) input.focus();
  }
</script>

{include file="customer/footer-public.tpl"}
