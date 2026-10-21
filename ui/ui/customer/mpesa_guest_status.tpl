{include file="customer/header-public.tpl"}
<style>
  @keyframes gradientShift {
    0%   { background-position: 0% 50%; }
    50%  { background-position: 100% 50%; }
    100% { background-position: 0% 50%; }
  }
  @keyframes spin { to { transform: rotate(360deg); } }
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
    box-shadow: 0 4px 18px rgba(0,0,0,0.3);
    margin-bottom: 16px;
    overflow: hidden;
  }
  .status-card-header {
    padding: 13px 18px;
    border-bottom: 1px solid rgba(255,255,255,0.1);
    font-weight: 700;
    font-size: 1rem;
    color: #fff;
    display: flex; align-items: center; gap: 8px;
  }
  .status-card-body { padding: 22px 18px; text-align: center; }
  .connected-badge {
    display: inline-flex; align-items: center; gap: 6px;
    background: rgba(67,160,71,0.2); border: 1px solid rgba(67,160,71,0.4);
    border-radius: 20px; padding: 4px 12px; color: #69f0ae;
    font-size: 0.8rem; font-weight: 600; margin-bottom: 14px;
  }
  .pulse { width: 8px; height: 8px; background: #69f0ae; border-radius: 50%; animation: pulse 1.5s ease-in-out infinite; }
  @keyframes pulse {
    0%,100% { opacity: 1; transform: scale(1); }
    50% { opacity: .4; transform: scale(.8); }
  }
  .metric-label { font-size: 0.78rem; color: rgba(255,255,255,0.55); text-transform: uppercase; letter-spacing: 1px; margin-bottom: 6px; }
  .metric-value { font-size: 2.6rem; font-weight: 800; font-family: 'Courier New', monospace; color: #69f0ae; line-height: 1.1; }
  .metric-value.data { font-size: 1.5rem; color: #fff; }
  .metric-sub { font-size: 0.82rem; color: rgba(255,255,255,0.5); margin-top: 4px; }
  .bar-track { width: 100%; height: 10px; background: rgba(255,255,255,0.12); border-radius: 6px; overflow: hidden; margin-top: 12px; }
  .bar-fill { height: 100%; background: linear-gradient(90deg, #69f0ae, #43a047); border-radius: 6px; transition: width .6s ease; }
  .btn-action {
    display: block; width: 100%; padding: 13px; border-radius: 8px; border: none;
    font-size: 1rem; font-weight: 700; cursor: pointer; text-align: center;
    text-decoration: none; margin-bottom: 10px; transition: transform .15s; box-sizing: border-box;
  }
  .btn-action:hover { transform: translateY(-1px); text-decoration: none; }
  .btn-continue { background: linear-gradient(135deg, #43a047, #1b5e20); color: #fff; }
  .btn-buy { background: linear-gradient(135deg, #533483, #0f3460); color: #fff; }
  .plan-name { font-size: 1.05rem; font-weight: 700; color: #fff; margin-bottom: 4px; }
  .hint { font-size: 0.78rem; color: rgba(255,255,255,0.45); text-align: center; margin-top: 8px; }
  .rofa-footer { text-align: center; font-size: 0.75rem; color: rgba(255,255,255,0.35); padding-bottom: 10px; }
  .rofa-footer a { color: rgba(255,255,255,0.45); text-decoration: none; }
</style>

<div class="rofa-header">
  <h2>&#x1F4F6; Rofatech Hotspot</h2>
  <p class="tagline">Session Status</p>
</div>

<div class="rofa-page">
  {if $st.active}
    <div class="status-card">
      <div class="status-card-header">&#x23F1; {Lang::T('Your Session')}</div>
      <div class="status-card-body">
        <div class="connected-badge" id="connectedBadge"><span class="pulse"></span> {Lang::T('Connected')}</div>
        <div class="plan-name">{$st.plan_name}</div>

        <div class="metric-label">{Lang::T('Time Left')}</div>
        <div class="metric-value" id="timeVal">--:--:--</div>
        <p class="metric-sub" id="timeHint">{Lang::T('Not connected — the countdown starts once you connect.')}</p>

        {if $st.has_data_limit}
          <div class="metric-label" style="margin-top:18px;">{Lang::T('Data Left')}</div>
          <div class="metric-value data" id="dataVal">--</div>
          <div class="metric-sub" id="dataOf"></div>
          <div class="bar-track"><div class="bar-fill" id="dataBar" style="width:100%"></div></div>
        {else}
          <div class="metric-label" style="margin-top:18px;">{Lang::T('Data Used')}</div>
          <div class="metric-value data" id="dataVal">--</div>
          <div class="metric-sub">{Lang::T('Unmetered')}</div>
        {/if}
      </div>
    </div>

    {if $continue_url}
      <a href="{$continue_url|escape:'html'}" class="btn-action btn-continue">&#x1F310; {Lang::T('Continue to Internet')}</a>
    {/if}
    <p class="hint">{Lang::T('Usage refreshes automatically every few seconds.')}</p>
  {else}
    <div class="status-card">
      <div class="status-card-header" style="background:rgba(233,69,96,0.2);">&#x274C; {Lang::T('No Active Session')}</div>
      <div class="status-card-body">
        <div style="font-size:2.4rem; margin-bottom:6px;">&#x1F625;</div>
        <p class="metric-sub">{Lang::T('Your package has expired or has no active session.')}</p>
        <a href="{Text::url('mpesa_guest/init')}" class="btn-action btn-buy" style="margin-top:14px;">&#x1F4B3; {Lang::T('Buy Internet')}</a>
      </div>
    </div>
  {/if}

  <div class="rofa-footer">
    <a href="{APP_URL}/pages/Privacy_Policy.html" target="_blank">Privacy</a>
    &nbsp;&bull;&nbsp;
    <a href="{APP_URL}/pages/Terms_of_Conditions.html" target="_blank">Terms</a>
    &nbsp;&bull;&nbsp;
    &copy; Rofatech
  </div>
</div>

{if $st.active}
<script>
(function () {
    var timeLeft = {$st.time_left};
    var connected = {if $st.connected}true{else}false{/if};
    var dataLimit = {$st.data_limit};
    var dataUsed = {$st.data_used};
    var dataLeft = {$st.data_left};
    var hasDataLimit = {if $st.has_data_limit}true{else}false{/if};
    var refreshUrl = '{Text::url('mpesa_guest/status/')}' + encodeURIComponent('{$code|escape:'javascript'}') + '&refresh=1';

    function fmtTime(s) {
        if (s < 0) s = 0;
        var h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60;
        return (h < 10 ? '0' : '') + h + ':' + (m < 10 ? '0' : '') + m + ':' + (sec < 10 ? '0' : '') + sec;
    }
    function fmtBytes(b) {
        if (b >= 1073741824) return (b / 1073741824).toFixed(2) + ' GB';
        if (b >= 1048576) return (b / 1048576).toFixed(1) + ' MB';
        if (b >= 1024) return Math.round(b / 1024) + ' KB';
        return b + ' B';
    }
    function render() {
        var t = document.getElementById('timeVal');
        var hint = document.getElementById('timeHint');
        if (t) {
            if (!connected) {
                // No router session yet: nothing runs down before Connect.
                t.textContent = '{Lang::T('Not connected')}';
            } else if (timeLeft > 0) {
                t.textContent = fmtTime(timeLeft);
            } else {
                t.textContent = '{Lang::T('Session ended')}';
            }
        }
        if (hint) {
            hint.style.display = connected ? 'none' : 'block';
        }
        var badge = document.getElementById('connectedBadge');
        if (badge) {
            badge.style.display = connected ? 'inline-flex' : 'none';
        }
        if (hasDataLimit) {
            document.getElementById('dataVal').textContent = fmtBytes(dataLeft) + ' left';
            document.getElementById('dataOf').textContent = 'of ' + fmtBytes(dataLimit);
            var pct = dataLimit > 0 ? Math.max(0, Math.min(100, (dataLeft / dataLimit) * 100)) : 100;
            document.getElementById('dataBar').style.width = pct + '%';
        } else {
            document.getElementById('dataVal').textContent = fmtBytes(dataUsed) + ' used';
        }
    }
    function tick() {
        if (connected && timeLeft > 0) { timeLeft--; render(); }
    }
    setInterval(tick, 1000);

    function refresh() {
        fetch(refreshUrl)
            .then(function (r) { return r.json(); })
            .then(function (d) {
                connected = !!d.connected;
                timeLeft = d.time_left;
                dataLimit = d.data_limit;
                dataUsed = d.data_used;
                dataLeft = d.data_left;
                hasDataLimit = !!d.has_data_limit;
                render();
            })
            .catch(function () {});
    }
    setInterval(refresh, 15000);

    render();
})();
</script>
{/if}
{include file="customer/footer-public.tpl"}
