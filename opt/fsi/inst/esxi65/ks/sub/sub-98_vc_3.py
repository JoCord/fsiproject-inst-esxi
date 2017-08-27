# 
#   join esxi to virtual center
#  
#   Copyright (C) 2012 virtuallyGhetto (William Lam), js
#   Reference: http://www.virtuallyghetto.com/2011/03/how-to-automatically-add-esxi-host-to.html
#
#   modifications for fsi & esxi 6.5 with python 3
#
import sys,re,os,urllib.request,urllib.parse,urllib.error,urllib.request,urllib.error,urllib.parse,base64,getopt,socket,time,socket,os,ssl

LZ="      "

host = socket.gethostname().split(".", 1)[0]
me=os.path.basename(__file__)
pidnr=os.getpid()
logfile=os.environ["logfile"]
kspath=os.environ["kspath"]
logtrace=1                   # 0 = info, 1 = debug, 2 = trace

log = open(logfile,'a')
srvlog = open(kspath + '/log/' + host + '.log','a')

def infmsg(text):
    ime = "%-30s" % me
    ipidnr = "%-6s" % str(pidnr)
    print((time.strftime('%H:%M:%S') + ' INFO   : ' + LZ + text))
    log.write(time.strftime('%Y.%m.%d-%H:%M:%S') + ' : ' + ipidnr + ' - ' + ime + ' INFO   : ' + LZ + text + "\n")
    srvlog.write(time.strftime('%Y.%m.%d-%H:%M:%S') + ' : ' + ipidnr + ' - ' + ime + ' INFO   : ' + LZ + text + "\n")

def debmsg(text):
    if logtrace >= 1:
        ime = "%-30s" % me
        ipidnr = "%-6s" % str(pidnr)
        print((time.strftime('%H:%M:%S') + ' DEBUG  : ' + LZ + text))
        log.write(time.strftime('%Y.%m.%d-%H:%M:%S') + ' : ' + ipidnr + ' - ' + ime + ' DEBUG  : ' + LZ + text + "\n")
        srvlog.write(time.strftime('%Y.%m.%d-%H:%M:%S') + ' : ' + ipidnr + ' - ' + ime + ' DEBUG  : ' + LZ + text + "\n")

def tracemsg(text):
    if logtrace >= 2:
        ime = "%-30s" % me
        ipidnr = "%-6s" % str(pidnr)
        print((time.strftime('%H:%M:%S') + ' TRACE  : ' + LZ + text))
        log.write(time.strftime('%Y.%m.%d-%H:%M:%S') + ' : ' + ipidnr + ' - ' + ime + ' TRACE  : ' + LZ + text + "\n")
        srvlog.write(time.strftime('%Y.%m.%d-%H:%M:%S') + ' : ' + ipidnr + ' - ' + ime + ' TRACE  : ' + LZ + text + "\n")

def errmsg(text):
    ime = "%-30s" % me
    ipidnr = "%-6s" % str(pidnr)
    print((time.strftime('%H:%M:%S') + ' ERROR  : ' + LZ + text))
    log.write(time.strftime('%Y.%m.%d-%H:%M:%S') + ' : ' + ipidnr + ' - ' + ime + ' ERROR  : ' + LZ + text + "\n")
    srvlog.write(time.strftime('%Y.%m.%d-%H:%M:%S') + ' : ' + ipidnr + ' - ' + ime + ' ERROR  : ' + LZ + text + "\n")
   

infmsg('Start joining vc - 1.05.09 - 27.2.2017')
infmsg('  Host: ' + host)
options, remainder = getopt.getopt(sys.argv[1:], 'v:u:p:s:d:h:a:c', ['vc=',
                                                                    'vusr=',
                                                                    'vpass=',
                                                                    'vcpass=',
                                                                    'dc=',
                                                                    'husr=',
                                                                    'hpass=',
                                                                    'hcpass=',
                                                                    ])

vcenter_server = "none"
datacenter = "none"
vc_username = "none"
vc_password = "none"
host_username = "none"
host_password = "none"

debmsg('  detect option')
for opt, arg in options:
    if opt in ('v', '--vc'):
        vcenter_server = arg
    elif opt in ('u', '--vusr'):
        vc_username = arg
    elif opt in ('p', '--vpass'):
        vc_password = arg
    elif opt in ('s', '--vcpass'):
        tracemsg('    arg: ' + arg)
        b_vc_password = base64.b64decode(arg)
        vc_password = b_vc_password.decode(encoding='UTF-8')
        vc_password = vc_password.rstrip('\n')
        tracemsg('    pass: ' + vc_password)
    elif opt in ('d', '--dc'):
        datacenter = arg
    elif opt in ('h', '--husr'):
        host_username = arg
    elif opt in ('a', '--hpass'):
        host_password = arg
    elif opt in ('c', '--hcpass'):
        tracemsg('    arg: ' + arg)
        b_host_password = base64.b64decode(arg)
        host_password = b_host_password.decode(encoding='UTF-8')
        host_password = host_password.rstrip('\n')
        tracemsg('    pass: ' + host_password)

debmsg('  check if all options exist')
if vcenter_server == "none":
    errmsg('no vc define')
    sys.exit(99)
else:
    infmsg('  vc = [' + vcenter_server + ']')

if vc_username == "none":
    errmsg('no vc user define')
    sys.exit(99)
else:
    infmsg('  vc user = [' + vc_username + ']')

if host_username == "none":
    errmsg('no host user define')
    sys.exit(99)
else:
    infmsg('  host user = [' + host_username + ']')

if datacenter == "none":
    ermsg("no dc define")
    sys.exit(99)
else:
    infmsg( "  dc = [" + datacenter + "]")
    datacenter = datacenter + "/host"

if host_password == "none":
    errmsg( "no host pw define")
    sys.exit(99)

if vc_password == "none":
    errmsg( "no vc user pw define")
    sys.exit(99)

debmsg('  ok')

# vCenter mob URL for findByInventoryPath
url = "https://" + vcenter_server + "/mob/?moid=SearchIndex&method=findByInventoryPath"
debmsg('   ==> web link: ' + url)

# Create global variables
global passman,authhandler,opener,req,page,page_content,nonce,headers,cookie,params,e_params,clusterMoRef


infmsg(' Starting join vCenter process ...')

try:
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    httpsHandler = urllib.request.HTTPSHandler(context = ctx)
except IOError as e:
    errmsg('Failed to set HTTPS handler:' + str(e))
    sys.exit(44)          
else:
    infmsg('  Succesfully built HTTPS handler')


# Code to build opener with HTTP Basic Authentication
try:
    passman = urllib.request.HTTPPasswordMgrWithDefaultRealm()
    tracemsg(' user: ' + vc_username)
    tracemsg(' pw: [' + vc_password + ']')
    
    passman.add_password(None,url,vc_username,vc_password)
    authhandler = urllib.request.HTTPBasicAuthHandler(passman)

    opener = urllib.request.build_opener(httpsHandler, authhandler)
    urllib.request.install_opener(opener)
except IOError as e:
    opener.close()
    errmsg('Failed HTTP Basic Authentication:' + str(e))
    sys.exit(33)          
else:
    infmsg(' Succesfully built HTTP Basic Authentication')

# Code to capture required page data and cookie required for post back to meet CSRF requirements
# Thanks to user klich - http://communities.vmware.com/message/1722582#1722582
try:
    debmsg('  Request url [' + url + '] now ...')
    req = urllib.request.Request(url)
except IOError as e:
    opener.close()
    errmsg('Failed to request url:' + str(e))
    sys.exit(22)
else:
    infmsg('    url request ok')

try:
    debmsg('  Open url now ... ')
    page = urllib.request.urlopen(req)
except IOError as e:
    opener.close()
    errmsg('cannot open MOB page request:' + str(e))
    sys.exit(22)
else:
    infmsg('    url open ok')

try:
    debmsg('   start reading page ...')
    page_content= page.read()
except IOError as e:
    opener.close()
    errmsg('Failed to retrieve MOB data:' + str(e))
    errmsg('Page content: [' + page_content + ']')
    sys.exit(23)
else:
    infmsg('  Succesfully requested MOB data')
    
    

# regex to get the vmware-session-nonce value from the hidden form entry
debmsg('  Get session nonce now ...')
reg = re.compile(b'name="vmware-session-nonce" type="hidden" value="?([^\s^"]+)"')

debmsg('  Search page for group content now ...')
tracemsg('  reg: [' + str(page_content) + ']')
m = reg.search(page_content)
if m:
    debmsg('  Found nonce - get it and use it')
    nonce = m.group(1)
    tracemsg('   nonce: ' + str(nonce))
else:
    debmsg('  No nonce - use none')



debmsg('  get the page headers to capture the cookie')
headers = page.info()
tracemsg('    headers: [' + str(headers) + ']')

cookie = headers.get("Set-Cookie")
tracemsg('    cookie: [' + str(cookie) + ']')

debmsg('  Code to search for vCenter datacenter')
if m:
    params = {'vmware-session-nonce':nonce,'inventoryPath':datacenter}
else:
    params = {'inventoryPath':datacenter}

e_params = urllib.parse.urlencode(params)
e_params = e_params.encode('utf-8')
req = urllib.request.Request(url, data=e_params, headers={'Cookie':cookie})

try:
    debmsg('  open url for get datacenter')
    page = urllib.request.urlopen(req)
except IOError as e:
    opener.close()
    errmsg('cannot open datacenter request:' + str(e))
    sys.exit(22)
else:
    infmsg('    url open ok')

try:
    debmsg('  read site')
    charset_encoding = page.info().get_content_charset()
    page = page.read().decode(charset_encoding)    
except IOError as e:
    opener.close()
    errmsg('cannot read datacenter request:' + str(e))
    sys.exit(22)
else:
    infmsg('    url read ok')

debmsg('  search for group')
# clusterMoRef = re.search('domain-c[0-9]*',page)
tracemsg('   Page: ' + page)
clusterMoRef = re.search('group-h[0-9]*',page)


if clusterMoRef:
    infmsg(' Succesfully located datacenter "' + datacenter + '"!')
else:
    opener.close()
    errmsg('Failed to find datacenter "' + datacenter + '"!')
    sys.exit(44)

debmsg('  Code to compute SHA1 hash')
cmd = "openssl x509 -sha1 -in /etc/vmware/ssl/rui.crt -noout -fingerprint"
tmp = os.popen(cmd)
tmp_sha1 = tmp.readline()
tmp.close()
s1 = re.split('=',tmp_sha1)
s2 = s1[1]
s3 = re.split('\n', s2)
sha1 = s3[0]

if sha1:
    infmsg('  Succesfully computed SHA1 hash: "' + sha1 + '"!')
else:
    opener.close()
    errmsg('Failed to compute SHA1 hash!')
    sys.exit(55)

debmsg('  Code to create ConnectHostSpec')
xml = 'b<spec xsi:type="HostConnectSpec"><hostName>%hostname</hostName><sslThumbprint>%sha</sslThumbprint><userName>%user</userName><password>%pass</password><force>1</force></spec>'

debmsg('  Code to extract IP Address to perform DNS lookup to add FQDN to vCenter')
hostip = socket.gethostbyname(socket.gethostname())

if hostip:
    infmsg('  Successfully extracted IP Address ' + hostip.strip())
else:
    opener.close()
    errmsg('Failed to extract IP Address!')
    sys.exit(66)

try:
    host = socket.getnameinfo((hostip, 0), 0)[0]
except IOError as e:
    errmsg('Failed to perform DNS lookup for ' + hostipt.strip())
    sys.exit(77)
else:
    infmsg('  Successfully performed DNS lookup for ' + hostip.strip() + ' is ' + host)

xml = xml.replace("%hostname",host)
xml = xml.replace("%sha",sha1)
xml = xml.replace("%user",host_username)
xml = xml.replace("%pass",host_password)

debmsg('  host usr: [' + host_username + ']')
tracemsg('   sha: [' + sha1 + ']')
debmsg('  hostname: [' + host + ']')
debmsg('  Code to join host to vCenter datacenter')

try:
    url = "https://" + vcenter_server + "/mob/?moid=" + clusterMoRef.group() + "&method=addStandaloneHost"
    if m:
        params = {'vmware-session-nonce':nonce,'spec':xml,'compResSpec':'','addConnected':'1','license':''}
    else:
        params = {'spec':xml,'compResSpec':'','addConnected':'1','license':''}

    # url = "https://" + vcenter_server + "/mob/?moid=" + clusterMoRef.group() + "&method=addHost"
    # params = {'vmware-session-nonce':nonce,'spec':xml,'asConnected':'1','resourcePool':'','license':''}
    debmsg('  url: ' + url)
    e_params = urllib.parse.urlencode(params)
    e_params = e_params.encode('utf-8')
    tracemsg('  url request')
    req = urllib.request.Request(url, e_params, headers={"Cookie":cookie})
    tracemsg('  url open')
    page = urllib.request.urlopen(req).read()
except IOError as e:
    opener.close()
    errmsg('Failed to join vCenter!')
    errmsg('HOSTNAME: ' + host)
    errmsg('USERNAME: ' + host_username)
    sys.exit(88)
else:
    infmsg('  Succesfully joined vCenter!')
    
    infmsg('  Logging off vCenter')
    url = "https://" + vcenter_server + "/mob/?moid=SessionManager&method=logout"
    if m:
        tracemsg('   with nonce: ' + str(nonce))
        params = {'vmware-session-nonce':nonce}
        e_params = urllib.parse.urlencode(params)
        e_params = e_params.encode('utf-8')
        req = urllib.request.Request(url, e_params, headers={"Cookie":cookie})
    else:
        tracemsg('   without nonce')
        req = urllib.request.Request(url, headers={"Cookie":cookie})
        
    page = urllib.request.urlopen(req).read()
        
sys.exit(0)        



