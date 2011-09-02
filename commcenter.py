import sys
import idaapi
import idautils

thumbRegId = idaapi.str2reg('T')

def isThumb(ea):
    global thumbRegId
    return idaapi.getSR(ea, thumbRegId) != 0

def process_func_for_string(str):
    loc = idaapi.find_binary(0, BADADDR, "\"%s" % str, 16, 0)
    if loc == BADADDR:
        print "String '%s' not found" % str
        return False
    xrEa = 0
    for xr in idautils.XrefsTo(loc):
        xrEa = xr.frm
        break
    if xrEa == 0:
        print "No xrefs to string '%s'" % str
        return False
    
    fn = idaapi.get_func(xrEa)

    if not fn:
        print "No function at xref to string '%s' (at %x)" % (str, xrEa)
        return False

    fnEa = fn.startEA

    if isThumb(fnEa):
        fnEa += 1

    print "// %s" % str
    print "{0x%x, 0x%x, 0x%x}," % (loc, xrEa, fnEa)
    
    return True

def main():
    strings = ["+xsimstate=1", "Sending internal notification %s", "activation ticket accepted... drive thru"]
    print "// TODO: version"
    print "// generated automatically with commcenter.py, IDA and IdaPython"

    for s in strings:
        if not process_func_for_string(s):
            raise Exception("Failed for string %s", s)

    print

if __name__ == '__main__':
    main()