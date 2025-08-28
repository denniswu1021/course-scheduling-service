package com.example.util;

import java.lang.reflect.Method;

public final class BeanUtil {
    private BeanUtil() {}

    public static void setIfExists(Object target, String setterName, Object value) {
        try {
            Method m = null;
            for (Method candidate : target.getClass().getMethods()) {
                if (candidate.getName().equals(setterName) && candidate.getParameterCount() == 1) {
                    m = candidate; break;
                }
            }
            if (m != null) {
                m.invoke(target, value);
            }
        } catch (Exception ignored) {
            // 若不存在對應 setter 就忽略
        }
    }
}