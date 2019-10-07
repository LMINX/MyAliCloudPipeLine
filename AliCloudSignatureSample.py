import sys
import urllib, urllib2
import base64
import hmac
import hashlib
from hashlib import sha1
import time
import uuid


def percent_encode(str):
    res = urllib.quote(str.decode(sys.stdin.encoding).encode('utf8'), '')
    res = res.replace('+', '%20')
    res = res.replace('*', '%2A')
    res = res.replace('%7E', '~')
    return res

def compute_signature(parameters, access_key_secret):
    sortedParameters = sorted(parameters.items(), key=lambda parameters: parameters[0])
   
    canonicalizedQueryString = ''
    
    for (k,v) in sortedParameters:
        canonicalizedQueryString += '&' + percent_encode(k) + '=' + percent_encode(v)  
    stringToSign = 'GET&%2F&' + percent_encode(canonicalizedQueryString[1:])
    print(stringToSign)
    print(canonicalizedQueryString[1:])
    h = hmac.new(access_key_secret + "&", stringToSign, sha1)
    print(h)
    signature = base64.encodestring(h.digest()).strip()
    print(signature)
    return signature


timestamp = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
parameters = { \

    'Format'        : 'JSON', \
    'Version'       : '2014-05-26', \
    'AccessKeyId'   : 'LTAI4FrLvwBAw4VrybhKEELr', \
    'SignatureVersion'  : '1.0', \
    'SignatureMethod'   : 'HMAC-SHA1', \
    'SignatureNonce'    : '97304d63-c4d2-4050-9cb9-01899a8b10ae', \
    'TimeStamp'         : '2019-09-30T10:04:49Z', \
    #'SignatureNonce'    : str(uuid.uuid1()), \
    #'TimeStamp'         : timestamp, \
    \

    'Action'            : 'Describeimages', \
    'RegionId'          : 'cn-hangzhou' ,\
    #'Host'              : 'bichen-ram.oss-cn-beijing.aliyuncs.com'
    'PageSize'          : '10' \
    }

access_key='Kzo721P1zNrn1vSdL2nyaqOCco1jsM' 
signature = compute_signature(parameters, access_key)
parameters['Signature'] = signature
print(parameters)



url = "http://ecs.aliyuncs.com/?" + urllib.urlencode(parameters)
print(url)
#request = urllib2.Request(url)
#conn = urllib2.urlopen(request)
#print conn.read()
print('----')
print(percent_encode('='))