# 레퍼런스 아카이브 (Flutter)

이미지·디자인 레퍼런스와 유튜브 영상을 모아서 정리하고, 무드보드로 배치해보는
**개인용 로컬 우선 아카이브 앱**입니다.

Windows · macOS · Linux · Android · iOS 에서 같은 코드로 동작합니다.

## 왜 다시 만드나

이전 버전은 브라우저에서 여는 단일 HTML 파일 PWA였습니다
([luseuss/reference-archive](https://github.com/luseuss/reference-archive) — 현역으로 계속 운영 중).
두 가지 이유로 Flutter로 재구축합니다.

1. 브라우저 탭이 아니라 **독립 실행되는 진짜 앱**을 원함
2. **폰에서도 쓰고 싶음** — Flutter를 고른 결정적 이유

## 현재 상태

1단계(뼈대와 저장) 진행 중입니다. 자세한 개발 단계와 설계 원칙은
[`CLAUDE.md`](CLAUDE.md)를, PR별 변경 이력은 [`update.md`](update.md)를 보세요.

## 개발 환경

- Flutter 3.47.1 (stable) / Dart 3.13.1
- 로컬 DB: drift
- Windows 데스크톱 빌드에는 Visual Studio Build Tools 2022의
  "C++를 사용한 데스크톱 개발" 워크로드가 필요합니다.
- Android 빌드에는 Android SDK가 필요합니다.

```
flutter pub get      # 패키지 설치
flutter run          # 실행 (연결된 기기 선택)
flutter test         # 테스트
```

## 라이선스

개인 프로젝트입니다.
