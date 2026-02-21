package me.devchanyoung.sensordetectionsystem.dto;

public record VehicleLogSavedEvent(
        String vehicleId,
        double speed,
        double rpm
) {
}

