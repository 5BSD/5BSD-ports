--- plugins/freebsd/meta/portmap/portmap.go.orig
+++ plugins/freebsd/meta/portmap/portmap.go
@@ -112,14 +112,16 @@
 			hostIP = "self"
 		}
 
+		// 5BSD runs OpenBSD PF: translation is a rule option, and
+		// these anchor rules are the last match for their packets.
 		res = append(res,
 			fmt.Sprintf(
-				"rdr pass %s proto %s from any to %s port %d -> %s port %d",
+				"pass in %s proto %s from any to %s port %d rdr-to %s port %d",
 				containerAF, pmap.Protocol, hostIP, pmap.HostPort, containerIP, pmap.ContainerPort))
 		if *config.SNAT {
 			res = append(res,
 				fmt.Sprintf(
-					"nat on %s %s proto %s from (lo0) to %s port %d -> (%s)",
+					"pass out on %s %s proto %s from (lo0) to %s port %d nat-to (%s)",
 					config.BrName, containerAF, pmap.Protocol, containerIP, pmap.ContainerPort, config.BrName))
 		}
 	}
@@ -187,7 +189,9 @@
 		return nil
 	}
 
-	cmd := exec.Command("pfctl", "-a", "cni-rdr/"+args.ContainerID[:32], "-F", "nat")
+	// OpenBSD pfctl has no "nat" flush modifier; the anchor's
+	// translation rules are its filter rules.
+	cmd := exec.Command("pfctl", "-a", "cni-rdr/"+args.ContainerID[:32], "-F", "rules")
 	return cmd.Run()
 }
 
