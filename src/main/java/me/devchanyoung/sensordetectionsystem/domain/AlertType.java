package me.devchanyoung.sensordetectionsystem.domain;


import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@RequiredArgsConstructor
public enum AlertType {
    SPEEDING("과속 의심"),
    SUDDEN_ACCEL("급과속 의심");

    private final String descriptcion;
}
