package me.devchanyoung.sensordetectionsystem.domain;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import lombok.*;    // getter, setter, builder

import java.time.LocalDateTime;


@Entity // 차량 센서 데이터 테이블과 매치될 수 있도록 Entity 이노테이션 설정
@Getter // 필드 값을 가져오는 메서드 getVehicleId() 자동 생성
@Setter // 필드 값을 설정하는 메서드 setVehicleId() 자동 생성
@NoArgsConstructor(access = AccessLevel.PROTECTED)  // JPA 사용을 위해 기본 생성자를 생성, 외부 생성을 차단하기 위해 protected
@AllArgsConstructor(access = AccessLevel.PRIVATE)   // 빌더 패턴 사용을 위한 전체 생성자, 외부 노출은 차단
@Builder // 가독성 좋은 객체 생성을 위해 빌더 패턴 적용
public class VehicleLog {
    @Id // id 필드가 테이블의 PK를 명시
    @GeneratedValue(strategy = GenerationType.IDENTITY) // DB가 자동으로 1씩 증가시키며 번호를 부여
    private Long id;

    private String vehicleId;   // 차량 고유 식별 번호
    private double speed;       // 속도 데이터
    private double rpm;         // RPM 데이터

    @Builder.Default // 빌더 사용 시 기본 값으로 아래 설정값을 사용
    private LocalDateTime createdAt = LocalDateTime.now(); // 데이터 생성 시점의 시간
}
