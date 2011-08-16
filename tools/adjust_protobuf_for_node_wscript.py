#!/usr/bin/env python2.4
# This short script modifies protobuf-for-node's wscript to exclude their samples,
# because they rely on a more recent version of protobuf than the one we ship with.
import sys
import shutil

if __name__ == '__main__':
  if len(sys.argv) <= 1:
    print ("%s: No argument specified!", __FILE__)
    exit()
  lFN1 = sys.argv[1]
  lFN2 = "%s.org" % lFN1
  shutil.copy(lFN1, lFN2)
  lF1 = open(lFN1, "w+")
  lF2 = open(lFN2, "r")
  lFound = False
  for lLine in lF2:
    if lLine.find("# Example service") >= 0:
      lFound = True
      lF1.writelines(["  if False:\n"])
    lL = ("", "  ")[lFound] + lLine
    lF1.writelines([lL])
  lF2.close()
  lF1.close()
