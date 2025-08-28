package com.example.rules;

import static org.junit.jupiter.api.Assertions.*;

import org.junit.jupiter.api.Test;
import org.kie.api.KieBase;
import org.kie.api.builder.Message;
import org.kie.api.builder.Results;
import org.kie.api.io.ResourceType;
import org.kie.api.runtime.KieSession;
import org.kie.internal.utils.KieHelper;

public class ConstraintsDrlCompilationTest {

    @Test
    void drlCompilesAndSessionCreates() {
        KieHelper helper = new KieHelper();
        helper.addResource(
            org.kie.internal.io.ResourceFactory.newClassPathResource("constraints.drl"),
            ResourceType.DRL);

        Results results = helper.verify();
        assertTrue(results.getMessages(Message.Level.ERROR).isEmpty(),
                "DRL compile errors: " + results.getMessages());

        KieBase kbase = helper.build();
        KieSession ksession = kbase.newKieSession();
        assertNotNull(ksession, "KieSession should be creatable");
        ksession.dispose();
    }
}