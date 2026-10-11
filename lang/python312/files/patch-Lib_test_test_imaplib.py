--- Lib/test/test_imaplib.py.orig
+++ Lib/test/test_imaplib.py
@@ -537,6 +537,18 @@
         self.assertEqual(data[0], b'Returned to authenticated state. (Success)')
         self.assertEqual(client.state, 'AUTH')
 
+    def test_control_characters(self):
+        client, server = self._setup(SimpleIMAPHandler)
+        client.login('user', 'pass')
+        for c in '\0\r\n':
+            for mailbox in (f'a{c}b', f'a{c}b'.encode()):
+                with self.assertRaises(ValueError):
+                    client.select(mailbox)
+        # Python 3.12 callers supply quoting for mailbox names.
+        typ, _ = client.select('"a\tb"')
+        self.assertEqual(typ, 'OK')
+        self.assertTrue(server.is_selected)
+
 
 class NewIMAPTests(NewIMAPTestsMixin, unittest.TestCase):
     imap_class = imaplib.IMAP4
