package com.example;

import org.kie.api.runtime.rule.RuleContext;

public class FakeHardSoftScoreHolder {
    private int hardScore = 0;
    private int softScore = 0;

    public void addHardConstraintMatch(RuleContext kcontext, int delta) {
        hardScore += delta;
    }
    public void addSoftConstraintMatch(RuleContext kcontext, int delta) {
        softScore += delta;
    }
    public int getHardScore() {
        return hardScore;
    }
    public int getSoftScore() {
        return softScore;
    }
}