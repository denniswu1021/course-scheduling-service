package com.example.rules;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;
import org.kie.api.KieServices;
import org.kie.api.runtime.KieContainer;
import org.kie.api.runtime.KieSession;

import java.io.InputStream;
import java.util.*;
import java.util.stream.Collectors;

@Path("/rules")
public class RulesDiagResource {

    private KieSession tryNewKieSession(KieContainer kc) {
        // 先試 named，失敗再試 default
        try { return kc.newKieSession("ksession-rules"); } catch (Throwable ignore) {}
        try { return kc.newKieSession(); } catch (Throwable ignore) {}
        return null;
    }

    @GET
    @Path("/_diag")
    @Produces(MediaType.APPLICATION_JSON)
    public Map<String, Object> diag() {
        Map<String, Object> out = new LinkedHashMap<>();

        boolean hasConstraintsDrl;
        try (InputStream is = getClass().getClassLoader().getResourceAsStream("constraints.drl")) {
            hasConstraintsDrl = (is != null);
        } catch (Exception e) {
            hasConstraintsDrl = false;
        }
        out.put("hasConstraintsDrl", hasConstraintsDrl);

        KieServices ks = KieServices.Factory.get();
        KieContainer kContainer;
        try {
            kContainer = ks.getKieClasspathContainer();
            out.put("containerCreated", true);
        } catch (Throwable t) {
            out.put("containerCreated", false);
            out.put("error", "Cannot create KieClasspathContainer: " + t.getClass().getSimpleName() + ": " + t.getMessage());
            return out;
        }

        // 嘗試建立 session
        KieSession ksession = tryNewKieSession(kContainer);
        out.put("ksessionCreatable", ksession != null);

        // 列出已編譯的 rule 名稱（若能建立 session）
        if (ksession != null) {
            try {
                var base = ksession.getKieBase();
                var ruleNames = base.getKiePackages().stream()
                        .flatMap(p -> p.getRules().stream().map(r -> r.getName()))
                        .sorted()
                        .collect(Collectors.toList());
                out.put("rules", ruleNames);
            } catch (Throwable t) {
                out.put("rulesError", t.getClass().getSimpleName() + ": " + t.getMessage());
            } finally {
                try { ksession.dispose(); } catch (Throwable ignore) {}
            }
        } else {
            out.put("rules", Collections.emptyList());
        }

        return out;
    }

    @GET
    @Path("/_list")
    @Produces(MediaType.APPLICATION_JSON)
    public List<String> listRules() {
        KieServices ks = KieServices.Factory.get();
        KieContainer kc = ks.getKieClasspathContainer();
        KieSession ksession = tryNewKieSession(kc);
        if (ksession == null) return Collections.emptyList();
        try {
            return ksession.getKieBase().getKiePackages().stream()
                    .flatMap(p -> p.getRules().stream().map(r -> r.getName()))
                    .sorted()
                    .collect(Collectors.toList());
        } finally {
            try { ksession.dispose(); } catch (Throwable ignore) {}
        }
    }
}
