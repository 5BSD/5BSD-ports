--- plugins/freebsd/meta/portmap/portmap.go.orig
+++ plugins/freebsd/meta/portmap/portmap.go
@@ -112,16 +112,25 @@
 			hostIP = "self"
 		}
 
+		// 5BSD runs OpenBSD PF: translation is a rule option, and
+		// these anchor rules are the last match for their packets.
 		res = append(res,
 			fmt.Sprintf(
-				"rdr pass %s proto %s from any to %s port %d -> %s port %d",
+				"pass in %s proto %s from any to %s port %d rdr-to %s port %d",
 				containerAF, pmap.Protocol, hostIP, pmap.HostPort, containerIP, pmap.ContainerPort))
-		if *config.SNAT {
-			res = append(res,
-				fmt.Sprintf(
-					"nat on %s %s proto %s from (lo0) to %s port %d -> (%s)",
-					config.BrName, containerAF, pmap.Protocol, containerIP, pmap.ContainerPort, config.BrName))
+		// Connections from the host itself leave through lo0, and the
+		// state pf creates there also matches them on their way back
+		// in, so redirect them on output.  The stack then routes them
+		// straight to the bridge; translate the source at the same
+		// time so the container can answer (127.0.0.1 included).
+		snat := ""
+		if *config.SNAT {
+			snat = fmt.Sprintf(" nat-to (%s:0)", config.BrName)
 		}
+		res = append(res,
+			fmt.Sprintf(
+				"pass out on lo0 %s proto %s from any to %s port %d rdr-to %s port %d%s",
+				containerAF, pmap.Protocol, hostIP, pmap.HostPort, containerIP, pmap.ContainerPort, snat))
 	}
 	return res, nil
 }
@@ -187,7 +196,9 @@
 		return nil
 	}
 
-	cmd := exec.Command("pfctl", "-a", "cni-rdr/"+args.ContainerID[:32], "-F", "nat")
+	// OpenBSD pfctl has no "nat" flush modifier; the anchor's
+	// translation rules are its filter rules.
+	cmd := exec.Command("pfctl", "-a", "cni-rdr/"+args.ContainerID[:32], "-F", "rules")
 	return cmd.Run()
 }
 
