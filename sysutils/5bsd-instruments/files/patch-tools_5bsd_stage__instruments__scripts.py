--- tools/5bsd/stage_instruments_scripts.py.orig
+++ tools/5bsd/stage_instruments_scripts.py
@@ -29,12 +29,12 @@
         key=str(source.relative_to(src))
         chosen=overrides/manifest[key]['file'] if key in manifest else source
         shutil.copy2(chosen,scripts/source.name)
-        provenance.append({'source':str(source),'sha256':hashlib.sha256(chosen.read_bytes()).hexdigest(),'corrected':key in manifest})
+        provenance.append({'source':'base/'+key,'sha256':hashlib.sha256(chosen.read_bytes()).hexdigest(),'corrected':key in manifest})
     for name,item in manifest.items():
         if name.startswith('cddl/'):
             shutil.copy2(overrides/item['file'], profiles/item['file'])
     for source in sorted((ROOT/'tools/5bsd/instrument_scripts').iterdir()):
         shutil.copy2(source, scripts/source.name)
-        provenance.append({'source':str(source),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'corrected':False})
+        provenance.append({'source':'toolkit/'+str(source.relative_to(ROOT)),'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'corrected':False})
     (bundle/'data/instrument-sources.json').write_text(json.dumps(provenance,indent=2)+'\n')
     print(f'Staged {len(provenance)} system DTrace scripts; corrections verified against source hashes.')
