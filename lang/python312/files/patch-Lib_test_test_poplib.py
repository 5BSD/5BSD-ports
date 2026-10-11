--- Lib/test/test_poplib.py.orig
+++ Lib/test/test_poplib.py
@@ -395,6 +395,13 @@
         self.assertIsNone(self.client.sock)
         self.assertIsNone(self.client.file)
 
+    def test_control_characters(self):
+        for c0 in map(chr, (*range(0x20), 0x7f)):
+            with self.assertRaises(ValueError):
+                self.client.user(f'user{c0}')
+            with self.assertRaises(ValueError):
+                self.client.pass_(f'{c0}pass')
+
     @requires_ssl
     def test_stls_capa(self):
         capa = self.client.capa()
