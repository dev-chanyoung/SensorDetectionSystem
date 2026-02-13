package me.devchanyoung.sensordetectionsystem.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Getter;
import lombok.NoArgsConstructor; 
import lombok.Setter;
import me.devchanyoung.sensordetectionsystem.domain.VehicleLog;

@Getter
@Setter
@NoArgsConstructor
public class VehicleLogRequest {

    @NotBlank(message = "차량 ID는 필수입니다.") // null, ""," " 모두 허용 안함
    private String vehicleId;

    @NotNull(message = "속도는 필수입니다.") // null 불가
    @Min(value = 0, message = "속도는 0 이상이어야 합니다.") // 음수 불가
    private double speed;

    @NotNull(message = "RPM은 필수입니다.")
    @Min(value = 0, message = "RPM은 0 이상이어야 합니다.")
    private double rpm;

    // DTO -> Entity 변환 메서드 (Service에서 쓰기 편하게)
    public VehicleLog toEntity() {
        return VehicleLog.builder()
                .vehicleId(this.vehicleId)
                .speed(this.speed)
                .rpm(this.rpm)
                .build();
    }
}