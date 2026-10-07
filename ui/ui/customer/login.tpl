{include file="customer/header-public.tpl"}

<div class="rofa-page">
    <p class="rofa-hint" style="text-align:center; margin-bottom:18px; font-size:1.05rem; color:rgba(255,255,255,0.85);">
        {Lang::T('Fast and reliable internet')}
    </p>

    <div class="rofa-card">
        <div class="rofa-card-header">
            {Lang::T('Log in to Member Panel')}
        </div>
        <div class="rofa-card-body">
            <p class="rofa-hint" style="margin-top:0; margin-bottom:18px;">
                {Lang::T('Login to buy a voucher for later use or connect through our hotspots for immediate use.')}
            </p>

            <form action="{Text::url('login/post')}" method="post">
                <input type="hidden" name="csrf_token" value="{$csrf_token}">

                <label class="rofa-label">
                    {if $_c['registration_username'] == 'phone'}
                        {Lang::T('Phone Number')}
                    {elseif $_c['registration_username'] == 'email'}
                        {Lang::T('Email')}
                    {else}
                        {Lang::T('Usernames')}
                    {/if}
                </label>
                <input type="text" class="rofa-input" name="username"
                    placeholder="{if $_c['country_code_phone']!= '' || $_c['registration_username'] == 'phone'}{$_c['country_code_phone']} {Lang::T('Phone Number')}{elseif $_c['registration_username'] == 'email'}{Lang::T('Email')}{else}{Lang::T('Usernames')}{/if}">

                <label class="rofa-label">{Lang::T('Password')}</label>
                <input type="password" class="rofa-input" name="password" placeholder="{Lang::T('Password')}">

                <button type="submit" class="rofa-btn rofa-btn-primary">{Lang::T('Login')}</button>

                {if $_c['disable_registration'] != 'noreg'}
                    <a href="{Text::url('register')}" class="rofa-btn rofa-btn-outline" style="margin-top:10px;">
                        {Lang::T('Register')}
                    </a>
                {/if}
            </form>

            <div style="text-align:center; margin-top:16px;">
                <a href="{Text::url('forgot')}" class="rofa-link">{Lang::T('Forgot Password')}</a>
            </div>
        </div>
    </div>

    <div style="text-align:center; margin-bottom:16px;">
        <a href="https://sovika.xyz" target="_blank" rel="noopener noreferrer" class="rofa-sovika">
            &#x1F680; {Lang::T('Powered by Sovika Technologies')}
        </a>
    </div>

    <div class="rofa-footer">
        <a href="javascript:showPrivacy()">Privacy</a>
        &nbsp;&bull;&nbsp;
        <a href="javascript:showTaC()">T &amp; C</a>
    </div>
</div>

{include file="customer/footer-public.tpl"}
