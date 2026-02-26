package me.devchanyoung.sensordetectionsystem.dto;


import lombok.AllArgsConstructor;
import lombok.Getter;
import me.devchanyoung.sensordetectionsystem.domain.DailyVehicleStats;

import java.time.LocalDate;

@Getter
@AllArgsConstructor
public class DailyStatsResponse {
    private LocalDate recordDate;
    private double avgSpeed;
    private double maxSpeed;
    private int safetyScore;

    public static DailyStatsResponse from(DailyVehicleStats stats) {
        return new DailyStatsResponse(
                stats.getRecordDate(),
                stats.getAvgSpeed(),
                stats.getMaxSpeed(),
                stats.getSafetyScore()
        );
    }
}
