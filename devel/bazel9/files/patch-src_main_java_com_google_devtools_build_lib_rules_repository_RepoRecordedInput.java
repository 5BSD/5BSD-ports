--- a/src/main/java/com/google/devtools/build/lib/rules/repository/RepoRecordedInput.java
+++ b/src/main/java/com/google/devtools/build/lib/rules/repository/RepoRecordedInput.java
@@ -581,9 +581,9 @@
       var fp = new Fingerprint();
       fp.addStrings(
           directoryListingValue.getDirents().stream()
-              .map(Dirent::getName)
+              .map(dirent -> dirent.getName() + "\0" + dirent.getType().name())
               .sorted()
               .collect(toImmutableList()));
       return fp.hexDigestAndReset();
