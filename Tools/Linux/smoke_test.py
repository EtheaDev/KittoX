"""Smoke test of a running KittoX application: home page, static resources,
login, then every view (and the first data page of each grid).

usage: python smoke_test.py <base url> <user> <password> [field=value ...]
  VIEWDIR=<app Home>/Metadata/Views also opens every view YAML found there, not only
  the ones linked from the first page.
Use 127.0.0.1 rather than localhost with WSL (see Tools/Linux/README.md).
"""
import re, sys, urllib.request, urllib.parse, urllib.error, http.client

base = sys.argv[1].rstrip('/') + '/'
user, pwd = sys.argv[2], sys.argv[3]
extra = dict(a.split('=', 1) for a in sys.argv[4:])
cookies = {}


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *a, **k):
        return None


opener = urllib.request.build_opener(NoRedirect)


def req(path, data=None, kx=False):
    url = urllib.parse.urljoin(base, path)
    h = {}
    if cookies:
        h['Cookie'] = '; '.join(f'{k}={v}' for k, v in cookies.items())
    if kx:
        h['X-KittoX'] = 'true'
        h['HX-Request'] = 'true'
    body = urllib.parse.urlencode(data).encode() if data is not None else None
    r = urllib.request.Request(url, data=body, headers=h)
    try:
        resp = opener.open(r, timeout=60)
        code, hdrs, text = resp.status, resp.headers, resp.read()
    except urllib.error.HTTPError as e:
        code, hdrs, text = e.code, e.headers, e.read()
    for c in hdrs.get_all('Set-Cookie') or []:
        k, v = c.split(';', 1)[0].split('=', 1)
        if v:
            cookies[k] = v
        else:
            cookies.pop(k, None)
    return code, text.decode('utf-8', 'replace')


fails = []
code, home = req('')
print(f'home {code} {len(home)}')
res = sorted(set(re.findall(r'(?:href|src)="(/[^"]+/res/[^"]+)"', home)))
bad = [(u, c) for u in res for c in [req(u)[0]] if c != 200]
print(f'resources {len(res) - len(bad)}/{len(res)} ok', bad or '')
fails += bad

form = {'UserName': user, 'Password': pwd, 'LocalStorageEnabled': 'true'}
for m in re.finditer(r'<select[^>]*name="([^"]+)"[^>]*>(.*?)</select>', home, re.S):
    opt = re.search(r'<option[^>]*value="([^"]*)"', m.group(2))
    if opt:
        form[m.group(1)] = opt.group(1)
form.update(extra)
code, text = req('kx/login', form, kx=True)
ok = code in (200, 303) and 'kx_token' in cookies
print(f'login {code} token={"kx_token" in cookies} fields={sorted(form)}')
if not ok:
    print('   ', re.sub(r'<[^>]+>', ' ', text)[:300].strip())
    sys.exit(1)

code, app = req('')
import os
views = sorted(set(re.findall(r'kx/view/([A-Za-z0-9_]+)', app)))
vd = os.environ.get('VIEWDIR')
if vd:
    views = sorted(set(views) | {f[:-5] for f in os.listdir(vd) if f.endswith('.yaml')})
print(f'app {code} {len(app)}  views in menu: {len(views)}')
for v in views:
    c, t = req(f'kx/view/{v}', kx=True)
    data = sorted(set(re.findall(r'hx-get="(kx/view/[^"?]*/data[^"]*)"', t)))
    dres = [(d, *req(d.replace('&amp;', '&'), kx=True)) for d in data[:1]]
    line = f'  {v:32} {c} {len(t):7}'
    for d, dc, dt in dres:
        rows = len(re.findall(r'<tr', dt))
        line += f'  data {dc} rows~{rows}'
        if dc != 200:
            fails.append((d, dc, re.sub(r'<[^>]+>', ' ', dt)[:200]))
    if c != 200:
        fails.append((v, c, re.sub(r'<[^>]+>', ' ', t)[:200]))
    err = re.search(r'(?i)(exception|error)[^<]{0,160}', t)
    if err and c == 200 and 'kx-error' in t:
        line += '  !! ' + err.group(0)[:100]
    print(line)

print('FAILURES:' if fails else 'ALL OK')
for f in fails:
    print('  ', f)
