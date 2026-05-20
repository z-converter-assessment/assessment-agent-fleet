# Credentials

OpenStack API 접근 credential 흐름. 채택 결정은 [ADR 0003](../adr/0003-credential-method.md).

## 방식
application credential (Keystone v3) 채택. 사용자 비번 디스크 노출 회피, Horizon 에서 개별 발급/회수 가능.

검토했으나 미채택:
- 사용자 비번 clouds.yaml — 비번 평문 노출, 회수 시 사용자 권한 전체 차단
- env 직접 export — shell history / process env 노출 리스크

## 파일 위치
- 경로: `~/.config/openstack/clouds.yaml`
- 권한: `0600` (사용자 read/write only)
- 디렉토리 권한: `0700`
- cloud entry name: `openstack` (Horizon 다운로드 기본값)

clouds.yaml 골격 (실제 값은 Horizon 다운로드본 사용):

```yaml
clouds:
  openstack:
    auth_type: v3applicationcredential
    auth:
      auth_url: http://<keystone-host>:5000
      application_credential_id: "<id>"
      application_credential_secret: "<secret>"
    region_name: RegionOne
    interface: public
    identity_api_version: 3
```

## 발급 + 배치 절차

1. Horizon -> Identity -> Application Credentials -> Create Application Credential
   - Name: 식별 가능한 이름 (예: `assessment-agent-fleet-iac`)
   - Roles: terraform/ansible 작업에 필요한 role 만 (보통 `member`)
   - Unrestricted: 체크 안 함 (이 AC 로 추가 AC 발급 차단)
   - Expiration: 정책에 따름. 무기한 또는 90일 권장
2. 생성 직후 한 번만 노출되는 secret 과 함께 `clouds.yaml` 다운로드
3. 점프호스트 (Windows) -> 인프라 VM 으로 scp 전송 (PowerShell)
   ```powershell
   scp $env:USERPROFILE\Downloads\clouds.yaml <user>@<iac>:.config/openstack/clouds.yaml
   ```
4. 인프라 VM 에서 권한 잠금
   ```bash
   chmod 0600 ~/.config/openstack/clouds.yaml
   ```
5. 점프호스트의 원본 파일 삭제 + 휴지통 비우기 (secret 디스크 잔존 방지)
   ```powershell
   Remove-Item $env:USERPROFILE\Downloads\clouds.yaml -Force
   Clear-RecycleBin -Force -Confirm:$false
   ```

## 사용
- `--os-cloud openstack` 옵션 또는 `export OS_CLOUD=openstack`
- terraform openstack provider 와 ansible openstack.cloud 모듈도 동일 clouds.yaml 자동 참조

## 검증
- `openstack --os-cloud openstack token issue` — token 발급
- `openstack --os-cloud openstack server list` — project 단위 server 조회
- `openstack --os-cloud openstack network list` — network 권한

## 회전 / 회수
- 회전: 새 AC 발급 -> clouds.yaml 교체 -> 검증 -> Horizon 에서 구 AC delete. 세부는 `docs/operations/rotate.md`
- 회수: Horizon 에서 AC delete 또는 인프라 VM 의 clouds.yaml 파일 삭제

## 운영 관찰
- 현재 클라우드의 keystone endpoint 는 HTTP. application credential secret 이 평문 전송. 사설망 내부 통신이라 작업 진행에 차단 없으나, HTTPS 전환은 클라우드 운영자 측 별도 트랙

## 의존
- terraform/providers.tf — OpenStack provider 가 본 credential 사용
- ansible openstack.cloud collection — 동일 clouds.yaml 참조
