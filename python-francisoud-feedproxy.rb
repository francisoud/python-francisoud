from google.appengine.ext import webapp
from google.appengine.ext.webapp.util import run_wsgi_app

import os
from google.appengine.ext.webapp import template

import urllib2
import sys
import re
import base64
from urlparse import urlparse

class FeedProxy:
    def __init__(self, theurl, username, password):
        self.theurl = theurl
        self.username = username
        self.password = password
    
    def get(self):
        req = urllib2.Request(self.theurl)
        try:
            handle = urllib2.urlopen(req)
        except IOError, e:
            # here we *want* to fail
            pass
        else:
            # If we don't fail then the page isn't protected
            print "This page isn't protected by authentication."
            sys.exit(1)

        if not hasattr(e, 'code') or e.code != 401:
            # we got an error - but not a 401 error
            print "This page isn't protected by authentication."
            print 'But we failed for another reason.'
            sys.exit(1)

        authline = e.headers['www-authenticate']
        # this gets the www-authenticate line from the headers
        # which has the authentication scheme and realm in it


        authobj = re.compile(
            r'''(?:\s*www-authenticate\s*:)?\s*(\w*)\s+realm=['"]([^'"]+)['"]''',
            re.IGNORECASE)
        # this regular expression is used to extract scheme and realm
        matchobj = authobj.match(authline)

        if not matchobj:
            # if the authline isn't matched by the regular expression
            # then something is wrong
            print 'The authentication header is badly formed.'
            print authline
            sys.exit(1)

        scheme = matchobj.group(1)
        realm = matchobj.group(2)
        # here we've extracted the scheme
        # and the realm from the header
        if scheme.lower() != 'basic':
            print 'This example only works with BASIC authentication.'
            sys.exit(1)

        base64string = base64.encodestring(
                        '%s:%s' % (self.username, self.password))[:-1]
        authheader =  "Basic %s" % base64string
        req.add_header("Authorization", authheader)
        try:
            handle = urllib2.urlopen(req)
        except IOError, e:
            # here we shouldn't fail if the username/password is right
            print "It looks like the username or password is wrong. (" + self.username + "/" + self.password + ")"
            sys.exit(1)
        thepage = handle.read()
        
        return thepage

class GoogleReader(webapp.RequestHandler):
    def get(self):
        theurl = self.request.get("url")
        username = self.request.get("username")
        password = self.request.get("password")
        fp = FeedProxy(theurl, username, password)
        self.response.headers['Content-Type'] = 'application/atom+xml'
        self.response.out.write(fp.get())

class TwitterFeed(webapp.RequestHandler):
    def get(self):
        username = self.request.get("username")
        password = self.request.get("password")
        fp = FeedProxy('http://twitter.com/statuses/friends_timeline.rss', username, password)
        self.response.headers['Content-Type'] = 'application/atom+xml'
        self.response.out.write(fp.get())

application = webapp.WSGIApplication([('/googlereader', GoogleReader),('/twitter', TwitterFeed)], debug=True)

def main():
    run_wsgi_app(application)

if __name__ == "__main__":
    main()