package com.example.domain;

import java.util.List;
import org.optaplanner.core.api.domain.solution.PlanningSolution;
import org.optaplanner.core.api.domain.solution.PlanningEntityCollectionProperty;
import org.optaplanner.core.api.domain.solution.ProblemFactCollectionProperty;
import org.optaplanner.core.api.domain.valuerange.ValueRangeProvider;
import org.optaplanner.core.api.score.buildin.hardsoft.HardSoftScore;
import org.optaplanner.core.api.domain.solution.PlanningScore;

import curriculumcourse.curriculumcourse.Course;
import curriculumcourse.curriculumcourse.Lecture;
import curriculumcourse.curriculumcourse.Period;
import curriculumcourse.curriculumcourse.Room;

@PlanningSolution
public class ScheduleSolution {

    private List<Room> roomList;
    private List<Period> periodList;
    private List<Course> courseList;
    private List<Lecture> lectureList;

    private HardSoftScore score;

    public ScheduleSolution() {
    }

    // === ????哨?蟡???????瞉???Lecture ?????? ===
    @ProblemFactCollectionProperty
    @ValueRangeProvider(id = "roomRange")
    public List<Room> getRoomList() { return roomList; }
    public void setRoomList(List<Room> roomList) { this.roomList = roomList; }

    @ProblemFactCollectionProperty
    @ValueRangeProvider(id = "periodRange")
    public List<Period> getPeriodList() { return periodList; }
    public void setPeriodList(List<Period> periodList) { this.periodList = periodList; }

    @ProblemFactCollectionProperty
    public List<Course> getCourseList() { return courseList; }
    public void setCourseList(List<Course> courseList) { this.courseList = courseList; }

    // === ?秋??? ===
    @PlanningEntityCollectionProperty
    public List<Lecture> getLectureList() { return lectureList; }
    public void setLectureList(List<Lecture> lectureList) { this.lectureList = lectureList; }

    @PlanningScore
    public HardSoftScore getScore() { return score; }
    public void setScore(HardSoftScore score) { this.score = score; }
}