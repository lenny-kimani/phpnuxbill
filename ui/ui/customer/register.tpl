{include file="customer/header-public.tpl"}

<div class="rofa-page">
    <p class="rofa-hint" style="text-align:center; margin-bottom:18px; font-size:1.05rem; color:rgba(255,255,255,0.85);">
        {Lang::T('Fast and reliable internet')}
    </p>

    <div class="rofa-card">
        <div class="rofa-card-header">
            {Lang::T('Register as Member')}
        </div>
        <div class="rofa-card-body">
            <form enctype="multipart/form-data" action="{Text::url('register/post')}" method="post">
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

                {if $_c['photo_register'] == 'yes'}
                    <label class="rofa-label">{Lang::T('Photo')}</label>
                    <input type="file" class="rofa-input" id="photo" name="photo" accept="image/*" required>
                {/if}

                <label class="rofa-label">{Lang::T('Full Name')}</label>
                <input type="text" class="rofa-input" id="fullname" value="{$fullname}" name="fullname" {if $_c['man_fields_fname'] neq 'no'}required{/if}>

                <label class="rofa-label">{Lang::T('Email')}</label>
                <input type="text" class="rofa-input" id="email" placeholder="xxxxxxx@xxxx.xx" value="{$email}" name="email" {if $_c['man_fields_email'] neq 'no'}required{/if}>

                <label class="rofa-label">{Lang::T('Home Address')}</label>
                <input type="text" class="rofa-input" name="address" id="address" value="{$address}" {if $_c['man_fields_address'] neq 'no'}required{/if}>

                {$customFields}

                <label class="rofa-label">{Lang::T('Password')}</label>
                <input type="password" class="rofa-input" id="password" name="password" required>

                <label class="rofa-label">{Lang::T('Confirm Password')}</label>
                <input type="password" class="rofa-input" id="cpassword" name="cpassword" required>

                <button type="submit" class="rofa-btn rofa-btn-success">{Lang::T('Register')}</button>
                <a href="{Text::url('login')}" class="rofa-btn rofa-btn-outline" style="margin-top:10px;">{Lang::T('Cancel')}</a>
            </form>

            <div style="text-align:center; margin-top:16px;">
                <a href="javascript:showPrivacy()">Privacy</a>
                &nbsp;&bull;&nbsp;
                <a href="javascript:showTaC()">T &amp; C</a>
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
