{include file="customer/header-public.tpl"}
<div class="hidden-xs" style="height:50px"></div>
<div class="row">
    <div class="col-sm-8">
        <div class="panel panel-info">
            <div class="panel-heading">{Lang::T('Announcement')}</div>
            <div class="panel-body">
                {include file="$_path/../pages/Announcement.html"}
            </div>
        </div>
    </div>
    <div class="col-sm-4">
        <div class="panel panel-primary">
            <div class="panel-heading">{Lang::T('Buy Internet Access')}</div>
            <div class="panel-body">
                <form action="{Text::url('mpesa_guest/pay')}" method="post">
                    <input type="hidden" name="csrf_token" value="{$csrf_token}">
                    <input type="hidden" name="mac" value="{$mac}">
                    <input type="hidden" name="ip" value="{$ip}">
                    <input type="hidden" name="router" value="{$router}">

                    <div class="form-group">
                        <label>{Lang::T('Phone Number')}</label>
                        <div class="input-group">
                            <span class="input-group-addon"><i class="glyphicon glyphicon-phone-alt"></i></span>
                            <input type="tel" class="form-control" name="phone" required
                                placeholder="254712345678"
                                pattern="^(?:254|0)?[17][0-9]{8}$">
                        </div>
                        <span class="help-block">{Lang::T('Enter the M-Pesa number that will receive the STK push')}</span>
                    </div>

                    <div class="form-group">
                        <label>{Lang::T('Select Plan')}</label>
                        <select name="plan" class="form-control" required>
                            <option value="">{Lang::T('-- Select Plan --')}</option>
                            {foreach $plans as $p}
                                <option value="{$p.id}">{$p.name_plan} - {Lang::moneyFormat($p.price)}</option>
                            {/foreach}
                        </select>
                    </div>

                    {if !empty($plans)}
                        <div class="btn-group btn-group-justified mb15">
                            <div class="btn-group">
                                <button type="submit" class="btn btn-success">{Lang::T('Pay with M-Pesa')}</button>
                            </div>
                        </div>
                    {else}
                        <div class="alert alert-warning">
                            {Lang::T('No plans available for this location')}
                        </div>
                    {/if}
                </form>
            </div>
        </div>
        <br>
        <center>
            <a href="{APP_URL}/pages/Privacy_Policy.html" target="_blank">Privacy</a>
            &bull;
            <a href="{APP_URL}/pages/Terms_of_Conditions.html" target="_blank">ToC</a>
        </center>
    </div>
</div>
{include file="customer/footer-public.tpl"}
