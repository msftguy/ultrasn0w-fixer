#!/usr/bin/python

import string, sys

def a2x(a):
    return ord(a) - ord('A')

def decode_2asc(s):
    out = ""
    for i in range(0, len(s)/2):
        out += chr(a2x(s[i*2]) * 16 + a2x(s[i * 2 + 1]))
    return out


def main():
    fIn = open(sys.argv[1], "r")
    inBytes = fIn.read()
    startOffs = inBytes.find("\";\"")
    if startOffs == -1:
        print "Could not locate payload start"
        return
    startOffs += 3
    endOffs = inBytes.find("\"", startOffs)
    if endOffs == -1:
        print "Could not locate payload end"
        return
    print "range: 0x%X to 0x%X" % (startOffs, endOffs)
    inBytes = inBytes[startOffs:endOffs]
    
    outBytes = decode_2asc(inBytes)
    for b in outBytes:
        print ("0x%02X, " % ord(b)),
    fOut = open(sys.argv[1] + ".payload", "w")
    fOut.write(outBytes)

if __name__ == '__main__': 
    main()
