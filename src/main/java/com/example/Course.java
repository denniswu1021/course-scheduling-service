package com.example;

public class Course {
    private int minimumWorkingDays;

    private String name;
    private int requiredDays;

    public Course(String name, int requiredDays) {
        this.name = name;
        this.requiredDays = requiredDays;
    }

    public String getName() {
        return name;
    }

    public int getRequiredDays() {
        return requiredDays;
    }

        public int getMinimumWorkingDays() {
        return this.minimumWorkingDays;
    }
        public void setMinimumWorkingDays(int minimumWorkingDays) {
        this.minimumWorkingDays = minimumWorkingDays;
    }
}