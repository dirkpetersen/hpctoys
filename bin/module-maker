#!/usr/bin/python3
#
# Generate a Easybuild compatible LMod lua module for applications that
# are not installed "old school" without using Easybuild 
# 
# It writes all currently loaded LMod modules as dependencies into the lua module
# which allows Administrators untrained in creating Easybuild packages to use 
# Easybuild toolchains and dependencies to offer software to their users. 
#
#import site; site.addsitedir('/app/lib/python3.6.8/lib/python3.6/site-packages/')
import sys, os, subprocess

__maintainer__ = 'Dirk Petersen'
__email__ = 'dipeit at the google mail'
__version__ = '1.0.0'
__date__ = 'April 15, 2022'

MOD_ROOT='/app/other/modules'

if len(sys.argv) < 2:
  print (' Please load the modules needed, switch to the root directory '
         'of the new application and enter the desired application ' 
         'name (without spaces) as first command argument and the '
         '(optional) version as second argument when you run "%s"\n' % 
         os.path.basename(sys.argv[0]))
  print(" Example: %s SAMTools 1.15" % os.path.basename(sys.argv[0]))
  sys.exit(1)

currdir = os.getcwd()
active_mods=subprocess.check_output('ml --terse list', shell=True,
     stderr=subprocess.STDOUT, universal_newlines=True).split('\n')
if active_mods[0]=='No modules loaded':
   active_mods=[]

appname = sys.argv[1]
appver =  os.path.basename(currdir)
if len(sys.argv) >= 3:
  appver = sys.argv[2]

bindir = os.path.join(currdir,'bin')
libdir = os.path.join(currdir,'lib')
if not os.path.isdir(os.path.join(MOD_ROOT,appname)):
  os.makedirs(os.path.join(MOD_ROOT,appname))
luafile = os.path.join(MOD_ROOT,appname,appver+'.lua')

with open(luafile, 'w') as f:
  f.write('local root = "%s"\n' % currdir)
  f.write('conflict("%s")\n' % appname)
  for m in active_mods:
    f.write('if not ( isloaded("%s") ) then\n' % m.strip())
    f.write('    load("%s")\n' % m.strip())
    f.write('end\n\n')
  if os.path.isdir(bindir):
    f.write('prepend_path("PATH", pathJoin(root, "bin"))\n')
  else:
    f.write('prepend_path("PATH", root)\n')
  if os.path.isdir(libdir):
    f.write('prepend_path("LIBRARY_PATH", pathJoin(root, "lib"))\n')
    f.write('prepend_path("LD_LIBRARY_PATH", pathJoin(root, "lib"))\n')

print('\n *** Added currently loaded modules as dependency ***')
os.system('ml --terse list')
print('\n Module "%s" version "%s" written to %s' % (appname,appver,luafile))
print('\n Try running "ml %s" or "ml %s/%s"\n' % (appname,appname,appver))
