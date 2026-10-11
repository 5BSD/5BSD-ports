5BSD: fix the X86Access fast path for accesses that straddle a page.

access_ptr() tested "offset <= ac->size1 - len" with uint16_t size1, so an
access starting in the first page and ending in the second wrapped the
subtraction and went through haddr1, writing past the first host page into
an unrelated guest page (seen as 0x80000000 at offset 0 from fstpt across a
page boundary).  Use "offset + len <= size1" and refuse haddr2 + delta when
the second page has no host mapping.  Not yet fixed upstream (master as of
2026-10-10).

--- target/i386/tcg/access.c.orig
+++ target/i386/tcg/access.c
@@ -68,16 +68,24 @@
     assert(offset <= ac->size1 - len);
     return ac->haddr1 + offset;
 #else
-    if (likely(offset <= ac->size1 - len)) {
+    assert(offset <= ac->size - len);
+    /*
+     * Note that ac->size1 - len must not be computed here: with
+     * len > size1 the unsigned subtraction wraps, and an access that
+     * straddles the page boundary would be done through haddr1, writing
+     * past the end of the first host page into whatever guest page
+     * happens to follow it in host memory.
+     */
+    if (likely(offset + len <= ac->size1)) {
         return ac->haddr1 + offset;
     }
-    assert(offset <= ac->size - len);
     /*
      * If the address is not naturally aligned, it might span both pages.
      * Only return ac->haddr2 if the area is entirely within the second page,
-     * otherwise fall back to slow accesses.
+     * otherwise fall back to slow accesses.  If the second page cannot be
+     * accessed directly (e.g. MMIO), haddr2 is NULL; use the slow path.
      */
-    if (likely(offset >= ac->size1)) {
+    if (likely(offset >= ac->size1) && ac->haddr2) {
         return ac->haddr2 + (offset - ac->size1);
     }
     return NULL;
