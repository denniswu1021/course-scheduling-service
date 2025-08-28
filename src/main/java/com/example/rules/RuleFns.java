package com.example.rules;

import java.util.Collection;

public final class RuleFns {
    private RuleFns() {}

    public static boolean stableOrder(Object x, Object y) {
        return System.identityHashCode(x) > System.identityHashCode(y);
    }

    public static boolean sizeLt(Collection<?> c, int n) {
        return c != null && c.size() < n;
    }
}
