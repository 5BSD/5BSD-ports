--- Lib/imaplib.py.orig
+++ Lib/imaplib.py
@@ -133,6 +133,8 @@
 _Literal = br'.*{(?P<size>\d+)}$'
 _Untagged_status = br'\* (?P<data>\d+) (?P<type>[A-Z-]+)( (?P<data2>.*))?'
 
+_control_chars = re.compile(b'[\x00\r\n]')
+
 
 
 class IMAP4:
@@ -994,6 +996,8 @@
             if arg is None: continue
             if isinstance(arg, str):
                 arg = bytes(arg, self._encoding)
+            if _control_chars.search(arg):
+                raise ValueError('NUL, CR and LF not allowed in commands')
             data = data + b' ' + arg
 
         literal = self.literal
