--- src/main/java/com/google/devtools/build/lib/rules/repository/RepoRecordedInput.java.orig
+++ src/main/java/com/google/devtools/build/lib/rules/repository/RepoRecordedInput.java
@@ -579,7 +579,7 @@
       var fp = new Fingerprint();
       fp.addStrings(
           directoryListingValue.getDirents().stream()
-              .map(Dirent::getName)
+              .map(dirent -> dirent.getName() + "\0" + dirent.getType().name())
               .sorted()
               .collect(toImmutableList()));
       return fp.hexDigestAndReset();
