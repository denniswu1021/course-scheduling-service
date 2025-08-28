package com.example;

public class CourseAssignment {
    private String courseName;
    private String day;

    public CourseAssignment(String courseName, String day) {
        this.courseName = courseName;
        this.day = day;
    }

    public String getCourseName() {
        return courseName;
    }

    public String getDay() {
        return day;
    }
}
