package com.example.rules;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

import jakarta.enterprise.inject.Instance;
import jakarta.inject.Inject;

import org.kie.api.runtime.KieRuntimeBuilder;
import org.kie.api.runtime.KieSession;
import org.kie.api.KieServices;
import org.kie.api.runtime.KieContainer;

// domain model
import curriculumcourse.curriculumcourse.*;

@Path("/rules")
@ApplicationScoped
@Produces(MediaType.APPLICATION_JSON)
@Consumes(MediaType.WILDCARD)
public class RulesTestResource {

    @Inject
    Instance<KieRuntimeBuilder> builderInstance;

    private KieSession newSession() {
        try {
            if (builderInstance != null && !builderInstance.isUnsatisfied() && !builderInstance.isAmbiguous()) {
                KieSession ks = builderInstance.get().newKieSession();
                if (ks != null) return ks;
            }
        } catch (Throwable ignore) {}
        try {
            KieServices ks = KieServices.Factory.get();
            KieContainer kc = ks.getKieClasspathContainer();
            KieSession s = null;
            try { s = kc.newKieSession("ksession-rules"); } catch (Throwable ignore) {}
            if (s == null) { try { s = kc.newKieSession(); } catch (Throwable ignore) {} }
            if (s != null) return s;
        } catch (Throwable ignore) {}
        throw new RuntimeException("Unable to create KieSession (builder+container both null). Check kmodule.xml & DRL packaging.");
    }

    @POST @Path("/testMinimumDays")
    public Response testMinimumDays() {
        KieSession ksession = newSession();
            ksession.setGlobal("scoreHolder", new com.example.rules.ScoreHolderShim());
        try {
            Teacher t = new Teacher("T1", 1L);
            Curriculum cur = new Curriculum("CUR-1", 1L);

            Course c = new Course();
            try { c.setMinWorkingDaySize(5); } catch (Throwable ignore) {}
            try { c.setTeacher(t); } catch (Throwable ignore) {}
            try {
                java.util.List<Curriculum> list = new java.util.ArrayList<>();
                list.add(cur);
                c.setCurriculumList(list);
            } catch (Throwable ignore) {}

            Day d1 = new Day(0, new java.util.ArrayList<>(), 1L);
            Day d2 = new Day(1, new java.util.ArrayList<>(), 2L);
            Day d3 = new Day(2, new java.util.ArrayList<>(), 3L);

            Timeslot ts1 = new Timeslot(0, 1L);
            Timeslot ts2 = new Timeslot(1, 2L);
            Timeslot ts3 = new Timeslot(2, 3L);

            Period p1 = new Period(d1, ts1, 1L);
            Period p2 = new Period(d2, ts2, 2L);
            Period p3 = new Period(d3, ts3, 3L);

            Room r = new Room("R-101", 50, 1L);

            Lecture l1 = new Lecture(); try { l1.setCourse(c); l1.setPeriod(p1); l1.setRoom(r); } catch (Throwable ignore) {}
            Lecture l2 = new Lecture(); try { l2.setCourse(c); l2.setPeriod(p2); l2.setRoom(r); } catch (Throwable ignore) {}
            Lecture l3 = new Lecture(); try { l3.setCourse(c); l3.setPeriod(p3); l3.setRoom(r); } catch (Throwable ignore) {}

            ksession.insert(t); ksession.insert(cur); ksession.insert(c);
            ksession.insert(d1); ksession.insert(d2); ksession.insert(d3);
            ksession.insert(ts1); ksession.insert(ts2); ksession.insert(ts3);
            ksession.insert(p1); ksession.insert(p2); ksession.insert(p3);
            ksession.insert(r);
            ksession.insert(l1); ksession.insert(l2); ksession.insert(l3);

            int fired = ksession.fireAllRules();
            return Response.ok(new Result(fired, "OK")).build();
        } finally { try { ksession.dispose(); } catch (Throwable ignore) {} }
    }

    @POST @Path("/test")
    public Response testSmoke() {
        KieSession ksession = newSession();
            ksession.setGlobal("scoreHolder", new com.example.rules.ScoreHolderShim());
        try {
            int fired = ksession.fireAllRules();
            return Response.ok(new Result(fired, "OK")).build();
        } finally { try { ksession.dispose(); } catch (Throwable ignore) {} }
    }

    public static class Result {
        public int fired;
        public String status;
        public Result(int fired, String status) { this.fired = fired; this.status = status; }
    }
}

