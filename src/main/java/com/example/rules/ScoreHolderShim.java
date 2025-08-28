package com.example.rules;

import org.kie.api.runtime.rule.RuleContext;

/** Shim for legacy DRL penalty calls on Drools 9. */
public class ScoreHolderShim {
    public void addHardPenalty(RuleContext kcontext, int weight) { /* no-op */ }
    public void addSoftPenalty(RuleContext kcontext, int weight) { /* no-op */ }

    // Common aliases kept for older DRLs:
    public void addHardConstraintMatch(RuleContext kcontext, int weight) { addHardPenalty(kcontext, weight); }
    public void addSoftConstraintMatch(RuleContext kcontext, int weight) { addSoftPenalty(kcontext, weight); }
}