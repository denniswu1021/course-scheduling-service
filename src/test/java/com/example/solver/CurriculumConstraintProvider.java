package com.example.solver;

import org.optaplanner.core.api.score.buildin.hardsoft.HardSoftScore;
import org.optaplanner.core.api.score.stream.Constraint;
import org.optaplanner.core.api.score.stream.ConstraintCollectors;
import org.optaplanner.core.api.score.stream.ConstraintFactory;
import org.optaplanner.core.api.score.stream.ConstraintProvider;
import org.optaplanner.core.api.score.stream.Joiners;

import curriculumcourse.curriculumcourse.Lecture;

public class CurriculumConstraintProvider implements ConstraintProvider {

    // 若 Course 物件本身有 getMinimumWorkingDays()，把這常數拿掉改讀該欄位
    private static final int MIN_WORKING_DAYS = 5;

    @Override
    public Constraint[] defineConstraints(ConstraintFactory factory) {
        return new Constraint[] {
                roomStability(factory),
                minimumWorkingDays(factory)
        };
    }

    /** Room stability：同一課程的 Lecture 被分配到不同 Room → 軟性扣分 */
    private Constraint roomStability(ConstraintFactory factory) {
        return factory.forEachUniquePair(Lecture.class,
                        Joiners.equal(Lecture::getCourse),
                        Joiners.filtering((l1, l2) ->
                                l1.getRoom() != null && l2.getRoom() != null
                                        && !l1.getRoom().equals(l2.getRoom())))
                .penalize(HardSoftScore.ONE_SOFT)
                .asConstraint("Room stability");
    }

    /** Minimum working days：每門課實際上課日數 < MIN_WORKING_DAYS → 依差額扣軟分 */
    private Constraint minimumWorkingDays(ConstraintFactory factory) {
        return factory.forEach(Lecture.class)
                // ★ 你的模型是 Lecture -> Period -> Day，所以用這條取 day，並先做 null guard
                .filter(l -> l.getPeriod() != null && l.getPeriod().getDay() != null)
                .groupBy(Lecture::getCourse,
                        ConstraintCollectors.countDistinct(l -> l.getPeriod().getDay()))
                .filter((course, dayCount) -> dayCount < MIN_WORKING_DAYS)
                .penalize(HardSoftScore.ONE_SOFT,
                        (course, dayCount) -> MIN_WORKING_DAYS - dayCount)
                .asConstraint("Minimum working days");
    }
}
