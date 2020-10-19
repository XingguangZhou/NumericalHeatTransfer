!  This is the exercise 5-2 program
!  This program is about to make the CD, FUS, Hybrid Scheme, and QUICK scheme.
!
!  FUNCTIONS:
!  MAIN - Entry point of console application.
!  Author      : Zhou Xingguang
!  Organization: Xi'an Jiaotong University - NuTHeL
!  Date        : 2020/10/17
!

!****************************************************************************
! Make some setup work,
! such as generate the grid, initial some parameters.
!****************************************************************************
    module SETUP
    implicit none
        public dx !The distance of each grid
        real*8 :: dx
        !define the Node structure.
        type :: Node
            real*8 :: x         !location
            real*8 :: temperature
            real*8 :: lambda    !heat conduction coefficient
            real*8 :: density
            real*8 :: velocity
        end type
        !define the Interface structure.
        type :: Surface
            real*8 :: x         !location
            real*8 :: lambda
            real*8 :: density
            real*8 :: velocity
        end type
    contains
        !begin to generate the grid with Practice B 
        subroutine Grid(NodeGroup, SurfaceGroup, N, length)
        implicit none
            type(Node), intent(inout)    :: NodeGroup(:)
            type(Surface), intent(inout) :: SurfaceGroup(:)
            real*8, intent(in)           :: length
            integer, intent(in)          :: N            !the number of the grids
            integer, parameter           :: fileid = 10
            integer                      :: i
            character(len=20)            :: filename='location.txt'
            logical                      :: alive
            dx = length / N
            !begin to generate the surface location
            SurfaceGroup(1)%x = 0
            do i=1, N
                SurfaceGroup(i+1)%x = SurfaceGroup(i)%x + dx
            end do
            !begin to generate the node location
            NodeGroup(1)%x = SurfaceGroup(1)%x
            NodeGroup(N+2)%x = SurfaceGroup(N+1)%x
            do i=1, N
                NodeGroup(i+1)%x = (SurfaceGroup(i)%x + SurfaceGroup(i+1)%x) / 2.D0
            end do
            !check the file status
            inquire(file=filename, exist=alive)
            if(alive) then
                write(*, *) "The Grid message file has generated, updating the data now..."
            else
                write(*, *) "The Grid message file has not benn generated, generating the data file now..."
            end if
            !begin to write the file
            open(unit=fileid, file=filename)
            write(fileid, *) "Node Loca:     Surface Loca:"
            do i=1, N+1
                write(fileid, "(F8.4, 8X, F8.4)") NodeGroup(i)%x, SurfaceGroup(i)%x
            end do
            write(fileid, "(F8.4, 8X, F8.4)") NodeGroup(N+2)%x
            close(fileid)
            return 
        end subroutine
        !
        !begin to generate the physical parameters to the Node and Surface.
        !
        subroutine Property(NodeGroup, SurfaceGroup)
        implicit none
            type(Node), intent(inout)    :: NodeGroup(:)
            type(Surface), intent(inout) :: SurfaceGroup(:)
            integer                      :: N               !the number of node
            integer                      :: i
            real*8                       :: const_lambda    !the constant heat conduciton parameter
            real*8                       :: const_density   !the constant density
            real*8                       :: const_velocity  !the constant velocity
            logical                      :: IsConstant
            logical                      :: alive
            integer, parameter           :: fileid = 10
            character(len=20)            :: filename='property.txt'
            N = size(NodeGroup, 1)
            write(*, *) "Constant Property?"
            read(*, *) IsConstant
            if(IsConstant == .false.) then
                !TODO: .....
                write(*, *) "Please note the property!"
                read(*, *)
            end if
            ! begin to read the constant property
            write(*, *) "Please input the heat conduction coefficient:"
            read(*, *) const_lambda
            write(*, *) "Please input the fluid velocity:"
            read(*, *) const_velocity
            write(*, *) "Please input the fluid density:"
            read(*, *) const_density
            !Only care about the parameters of the INTERNAL NODE!
            do i=2, N-1
                NodeGroup(i)%lambda = const_lambda
                NodeGroup(i)%velocity = const_velocity
                NodeGroup(i)%density = const_density
            end do
            !
            !all surface property should be given!
            !
            do i=1, N-1
                SurfaceGroup(i)%lambda = const_lambda
                SurfaceGroup(i)%velocity = const_velocity
                SurfaceGroup(i)%density = const_density
            end do
            !check the file status
            inquire(file=filename, exist=alive)
            if(alive) then
                write(*, *) "Property file is ready, updating the data now..."
            else
                write(*, *) "Property file is not ready, writing the data now..."
            end if
            !begin to write the file
            !we should pay more attention to the surface group property.
            open(unit=fileid, file=filename)
            write(fileid, *) "Node HC:       Surface HC:"
            do i=1, N-1
                write(fileid, "(F8.4, 8X, F8.4)") NodeGroup(i)%lambda, SurfaceGroup(i)%lambda
            end do
            write(fileid, *) "Node density:       Surface density:"
            do i=1, N-1
                write(fileid, "(F8.4, 8X, F8.4)") NodeGroup(i)%density, SurfaceGroup(i)%density
            end do
            write(fileid, *) "Node V:       Surface V:"
            do i=1, N-1
                write(fileid, "(F8.4, 8X, F8.4)") NodeGroup(i)%velocity, SurfaceGroup(i)%velocity
            end do
            close(fileid)
            return
        end subroutine
    end module
!****************************************************************************
!
!  MODULE: FirstOrderUpwind
!  METHOD: Finite Volume Method
!  PURPOSE:  Calculate the first order upwind scheme on -----
!            1-D steady state without internal heat source problem.
!
!****************************************************************************
    module FUS
    use SETUP
    implicit none
    contains
        ! TDMA coefficient matrix generation.
        !
        ![ap1  ae1                                   ]
        !|aw2  ap2  ae2                              |
        !|     aw3  ap3  ae3                         |
        !|          aw4  ap4  ae4                    |
        !|                ...                        |
        !|                  ...                      |
        !|                    ...                    | 
        !|                      awn-1  apn-1  aen-1  |
        ![                               awn  apn    ]
        !
        !Generate the coefficient matrix of TDMA
        !because of non-source, then there is no 'b' inside the matrix function.
        subroutine GenerateModulusInFUS(AE, AP, AW, SurfaceGroup)
        implicit none
            real*8, intent(inout)     :: AE(:)
            real*8, intent(inout)     :: AP(:)
            real*8, intent(inout)     :: AW(:)
            type(Surface), intent(in) :: SurfaceGroup(:)
            integer                   :: N
            integer                   :: i
            logical                   :: alive
            character(len=20)         :: filename='FUS-COEFF.txt'
            integer, parameter        :: fileid=10
            N = size(SurfaceGroup,1)
            !because of the fluid velocity has two direction of 1-D axis ( v>0 or v<0 ),
            !so we need to distinguish the two style upwind scheme.
            if(SurfaceGroup(2)%velocity > 0) then
                goto 1000
            else
                goto 2000
            end if
            !<1>. if v>0:
1000        AW(1) = 0.D0         !triangle-diagonal matrix condition
            do i=2, N+1
                AW(i) = SurfaceGroup(i-1)%lambda/dx + SurfaceGroup(i-1)%density*SurfaceGroup(i-1)%velocity
            end do
            AE(N+1) = 0.D0          !triangle-diagonal matrix condition
            do i=1, N
                AE(i) = SurfaceGroup(i)%lambda/dx
            end do
            goto 3000
            !<2>. if v<0
            !begin to calculate the array AE
2000        AW(1) = 0.D0
            do i=2, N+1
                AW(i) = SurfaceGroup(i-1)%lambda/dx
            end do
            !reverse the array AW
            !AW = AW(N+1:1:-1)
            !begin to calculate the array AE
            AE(N+1) = 0.D0
            do i=1, N
                AE(i) = SurfaceGroup(i)%lambda/dx + SurfaceGroup(i)%density*dabs(SurfaceGroup(i)%velocity)
            end do
            !reverse the array AE
            !AE = AE(N+1:1:-1)
            !Get array AP, AP = AW + AE, use the Fortran built-in array operation.
3000        AP = AW + AE
            !check the file status
            inquire(file=filename, exist=alive)
            if(alive) then
                write(*, *) "The COEFF file is ready, updating the data now..."
            else
                write(*, *) "The COEFF file is not ready, writing the data now..."
            end if
            !begin to write the COEFF file
            open(unit=fileid, file=filename)
            write(fileid, *) "COEFF OF TDMA:"
            write(fileid, *) "  AW               AP                AE"
            do i=1, N+1
                write(fileid, "(F8.4,8X,F8.4,8X,F8.4)") AW(i), AP(i), AE(i)
            end do
            close(fileid)
            return
        end subroutine
        !print some message of the node and interface(surface).
        subroutine PrintMessage(NodeGroup, SurfaceGroup)
        implicit none
            type(Node), intent(in)    :: NodeGroup(:)
            type(Surface), intent(in) :: SurfaceGroup(:)
            integer                   :: i, N
            N = size(SurfaceGroup, 1)
            write(*, *) "*********���ô�ӡ��Ϣ����*********"
            write(*, *)
            write(*, *) "�ڵ����꣺      �������꣺"
            do i=1, N
                write(*, "(F8.4,8X,F8.4)") NodeGroup(i)%x, SurfaceGroup(i)%x
            end do
            write(*, "(F8.4)") NodeGroup(N+1)%x
            write(*, *) "*********************************"
            !TODO: print more message
            return
        end subroutine
    end module
!****************************************************************************
!
!  MODULE: CD
!  METHOD: Finite Volume Method
!  PURPOSE:  Calculate the Central Difference scheme on -----
!            1-D steady state without internal heat source problem.
!
!****************************************************************************
    module CD
    use SETUP
    implicit none
    contains
        subroutine GenerateModulusInCD(AE, AP, AW, SurfaceGroup)
        implicit none
            real*8, intent(inout)          :: AE(:)
            real*8, intent(inout)          :: AP(:)
            real*8, intent(inout)          :: AW(:)
            type(Surface), intent(in) :: SurfaceGroup(:)
            integer                        :: N
            integer                        :: i
            logical                        :: alive
            character(len=20)              :: filename = 'CD_COEFF.txt'
            integer, parameter             :: fileid = 10
            N = size(SurfaceGroup, 1)      ! number of elements in SurfaceGroup array
            ! This way, we only discuess the V > 0, also known as the velocity is goto the 
            ! x-axis positive direction.
            ! And now, we begin to generate the coeffcient matrix, which made by AE, AP, AW.
            AW(1) = 0.D0
            do i=2, N+1
                AW(i) = SurfaceGroup(i-1)%lambda/dx + 0.5*SurfaceGroup(i-1)%density*SurfaceGroup(i-1)%velocity
            end do
            AE(N+1) = 0.D0
            do i=1, N
                AE(i) = SurfaceGroup(i)%lambda/dx - 0.5*SurfaceGroup(i)%density*SurfaceGroup(i)%velocity
            end do
            ! Use the Fortran built-in array operation to calculate the AP
            AP = AE + AW
            ! begin to record the AP, AW, AE in the files
            ! check the file status
            inquire(file=filename, exist=alive)
            if(alive) then
                write(*, *) "The CD-COEFF file is ready, updating the data now..."
            else
                write(*, *) "The CD-COEFF file is not ready, writing the data now..."
            end if
            ! begin to write the CD-COEFF file
            open(unit=fileid, file=filename)
            write(fileid, *) "CD-COEFF OF TDMA"
            write(fileid, *) "  AW               AP                AE"
            do i=1, N+1
                write(fileid, "(F8.4,8X,F8.4,8X,F8.4)") AW(i), AP(i), AE(i)
            end do
            close(fileid)
            return
        end subroutine
    end module
!****************************************************************************
!
!  MODULE: HS
!  METHOD: Finite Volume Method
!  PURPOSE:  Calculate the Hybrid Scheme on -----
!            1-D steady state without internal heat source problem.
!
!****************************************************************************
    module HS
    use SETUP
    implicit none
    contains
        subroutine GenerateModulusInHS(AE, AP, AW, SurfaceGroup)
        implicit none
            real*8, intent(inout)          :: AE(:)
            real*8, intent(inout)          :: AP(:)
            real*8, intent(inout)          :: AW(:)
            type(Surface), intent(in)      :: SurfaceGroup(:)
            integer                        :: N
            integer                        :: i
            logical                        :: alive
            character(len=20)              :: filename = 'HS-COEFF.txt'
            integer, parameter             :: fileid = 10
            real*8                         :: GridPe        !���񱴿�����������ȷ����ϸ�ʽ�ķ��̡�
            real*8                         :: AEDE          ! AE OVER DE, this is a coeffcient.
            N = size(SurfaceGroup, 1)
            ! This way, we only discuess the V > 0, also known as the velocity is goto the 
            ! x-axis positive direction.
            ! And now, we begin to generate the coeffcient matrix, which made by AE, AP, AW.
            ! First, we should to get the Grid Pe and make sure which model we should to choose.
            GridPe = SurfaceGroup(1)%density*SurfaceGroup(1)%velocity*dx / SurfaceGroup(1)%lambda
            if(GridPe > 2.0) then
                AEDE = 0.D0
            else if(GridPe < -2) then
                AEDE = -GridPe
            else
                AEDE = 1 - 0.5*GridPe
            end if
            ! according to the AEPE, try to generate the AE, AW and AP
            AE(N+1) = 0.D0
            do i=1, N
                AE(i) = (SurfaceGroup(i)%lambda/dx) * AEDE
            end do
            AW(1) = 0.D0
            do i=2, N+1
                AW(i) = (SurfaceGroup(i-1)%lambda/dx)*((AE(i-1)/(SurfaceGroup(i-1)%lambda/dx)) + GridPe)
            end do
            ! use the Fortran built-in array operation.
            AP = AW + AE
            ! begin to record the AP, AW and AE in file.
            ! check the file status
            inquire(file=filename, exist=alive)
            if(alive) then
                write(*, *) "The HS-COEFF file is ready, updating the data now..."
            else
                write(*, *) "The HS-COEFF file is not ready, writing the data now..."
            end if
            ! begin to write the file.
            open(unit=fileid, file=filename)
            write(fileid, *) "COEFF OF TDMA:"
            write(fileid, *) "  AW               AP                AE"
            do i=1, N+1
                write(fileid, "(F8.4,8X,F8.4,8X,F8.4)") AW(i), AP(i), AE(i)
            end do
            close(fileid)
            return 
        end subroutine
    end module  
!*****************************************************************************************
!
!  MODULE: QUICK
!  METHOD: Finite Volume Method
!  PURPOSE:  Calculate the QUICK method on -----
!            1-D steady state without internal heat source problem.
!  DATE: 2020/10/18 ��ͼʹ����١��ͬѧ�ľ���ֱ����ⷽ��������QUICK��ʽ��ɢ����
!        �����˼��Ϊ��AE,AP,AW,AEE,AWWȫ���ŵ�������Ⱥ���ߣ�ͬʱAEE, AWW, AE, AW�ڳ�ʼ
!        ��������в��迼�ǣ��߽������ڵȺ��ұ߻������b�����ĵ�һ��Ԫ�������һ��Ԫ�ض�Ӧ��
!        ��������߽��¶����յ�߽��¶ȣ�b��������Ԫ�ؾ�Ϊ0����
!        ����ϵ�������ǰ���������һ�п���ʹ�ýϵͽ׸�ʽ����ɢ���һ��ӭ��������Ĳ�֣���
!        �����������в�����AEE��AWW����ϵ��������һ�����ԽǾ���
!
!*****************************************************************************************
    module QUICK
    use FUS
    use SETUP
    contains 
        subroutine GenerateModulusInQUICK(MATRIX_QUICK, b, SurfaceGroup, t1, tm1)
        implicit none
                real*8, intent(inout)     :: MATRIX_QUICK(:, :)        ! ϵ������
                real*8, intent(inout)     :: b(:)                      ! �Ⱥ��ұ߰����߽�������������
                type(Surface), intent(in) :: SurfaceGroup(:)           ! ��������ϵ������ǰ���к����һ�е�ϵ��
                real*8, intent(in)        :: t1, tm1
                real*8                    :: GridPe                    ! ���񱴿�����������ϵ������ʱʹ�á�
                integer                   :: N, i
                N = size(MATRIX_QUICK, 1)
                !�������񱴿�����
                GridPe = SurfaceGroup(1)%density*SurfaceGroup(1)%velocity*dx / SurfaceGroup(1)%lambda
                write(*, *) "GridPe", GridPe
                !��ʼ����ΪQUICK��ϵ������ǰ�漸��Ԫ�ؽ��и�ֵ��ʹ�����Ĳ�ָ�ʽ���д��棩
                !ϵ�������һ����ڶ���ʹ�����Ĳ�ֽ���
                MATRIX_QUICK(1, 1) = (1-0.5*GridPe)*2+GridPe
                MATRIX_QUICK(1, 2) = -(1-0.5*GridPe)
                MATRIX_QUICK(2, 1) = -(GridPe+1-0.5*GridPe)
                MATRIX_QUICK(2, 2) = (GridPe+1-0.5*GridPe)+(1-0.5*GridPe)
                MATRIX_QUICK(2, 3) = -(1-0.5*GridPe)
                !�м�ϵ������ͨ�����񱴿��������м���
                do i=3, N-1
                    MATRIX_QUICK(i, i-2) = GridPe / 8
                    MATRIX_QUICK(i, i-1) = -(1+7*GridPe/8)
                    MATRIX_QUICK(i, i+1) = -(1-0.375*GridPe)
                    MATRIX_QUICK(i, i)   = 2 + 0.375*GridPe
                end do
                !ϵ���������һ��ʹ�����Ĳ�ֽ���
                MATRIX_QUICK(N, N-2) = GridPe / 8
                MATRIX_QUICK(N, N-1) = -(1+7*GridPe/8)
                MATRIX_QUICK(N, N)   = 2 + 0.375*GridPe
                !Ϊ������Ⱥ��ұߵ���������ֵ�趨�߽�����
                b = 0
                b(1) = t1*(GridPe+1-0.5*GridPe)
                b(N) = tm1*(1-0.375*GridPe)            
                write(*, *) "======================== MATRIX ========================"
                do i=1, N
                    write(*, *) MATRIX_QUICK(i, :)
                end do
                return 
        end subroutine
        !ʹ�ø�˹��Ԫ��������ⷽ����
        subroutine GaussMethod(matrix, b, x)
        implicit none
            real*8, intent(inout) :: matrix(:, :)
            real*8, intent(inout) :: b(:)
            real*8, intent(out)   :: x(:)
            integer               :: N
            integer               :: i, j
            real*8                :: coeff
            N = size(matrix, 1)
            !��Ԫ����
            do i=1, N-1
                do j=i+1, N
                    coeff = matrix(j, i) / matrix(i, i)
                    matrix(j, :) = matrix(j, :) - matrix(i, :) * coeff
                    b(j) = b(j) - b(i)*coeff
                end do
            end do
            !�ش�����
            x(N) = b(N) / matrix(N, N)
            do i=N-1, 1, -1
                do j=N, i+1, -1
                    b(i) = b(i) - matrix(i, j) * x(j)
                end do
                x(i) = b(i) / matrix(i, i)
            end do
            return 
        end subroutine
    end module 
!****************************************************************************
!
!  MODULE: TDMA
!  METHOD: Use TDMA method to solve the 1-D convection-diffusion equation
!
!****************************************************************************
    module TDMA
    use SETUP
    implicit none
    contains
        subroutine SolvePQ(P, Q, A, B, C, t1, tm1, v_direction)
        implicit none
            real*8, intent(inout) :: P(:)
            real*8, intent(inout) :: Q(:)
            real*8, intent(in)    :: A(:)
            real*8, intent(in)    :: B(:)
            real*8, intent(in)    :: C(:)
            real*8, intent(in)    :: t1
            real*8, intent(in)    :: tm1
            logical, intent(in)   :: v_direction !record the fluid flow direction.
            real*8                :: coeff=0.D0  !record the temp parameter.
            integer               :: fileid=10
            character(len=20)     :: filename='PQ.txt'
            integer               :: i
            integer               :: N
            N = size(A, 1)                       !��ʱ��A��Ԫ�ظ�����ڵ������ͬ
            if(v_direction) then ! V > 0
                !The first kind boundary condition:
                P(1) = 0
                Q(1) = t1
            else                 ! V < 0
                P(1) = 0
                Q(1) = t1
            end if
            do i=2, N
                coeff = A(i)-C(i)*P(i-1)
                P(i) = B(i) / coeff
                Q(i) = (C(i)*Q(i-1)) / coeff
            end do
            !begin to write the file.
            open(unit=fileid, file=filename)
            write(fileid, *) "P         Q"
            do i=1, N
                write(fileid, "(F8.4, 8X, F8.4)") P(i), Q(i)
            end do
            close(fileid)
            return
        end subroutine
        !Solve the temperature of each node.
        subroutine SolveT(P, Q, NodeGroup)
        implicit none
            real*8, intent(inout)     :: P(:)              !P��Q��Ԫ�ظ���������ڵ�������ͬ����������ʱ���ò�����ô���PQ
            real*8, intent(inout)     :: Q(:)
            type(Node), intent(inout) :: NodeGroup(:)
            integer                   :: N
            integer                   :: i
            N = size(NodeGroup, 1)
            !�ӵ����ڶ����ڵ㿪ʼ�ش�����¶�
            do i=N-1, 2, -1
                NodeGroup(i)%temperature = P(i)*NodeGroup(i+1)%temperature + Q(i)
            end do
            return
        end subroutine
    end module
    !
    !The entry of the program
    !
    program main
    use SETUP
    use FUS        ! ������һ��ӭ���ʽ
    use CD         ! ���Ĳ�ָ�ʽ
    use HS         ! ��ϸ�ʽ
    use QUICK
    use TDMA
    implicit none
        real*8                     :: length !the length of this physical problem.
        real*8, allocatable        :: A(:)
        real*8, allocatable        :: B(:)
        real*8, allocatable        :: C(:)
        real*8, allocatable        :: P(:)
        real*8, allocatable        :: Q(:)
        type(Node), allocatable    :: NodeGroup(:)
        type(Surface), allocatable :: SurfaceGroup(:)
!QUICK NEED
        real*8, allocatable        :: MATRIX_QUICK(:, :)
        real*8, allocatable        :: B_QUICK(:)
        real*8, allocatable        :: x(:)
!QUICK END
        integer                    :: i
        integer                    :: N
        integer, parameter         :: fileid = 10
        logical                    :: alive
        character(len=20)          :: filename = 'temperature.csv'
        logical                    :: v_direction
        write(*, *) "Please input the length of this problem:"
        read(*, *) length
        write(*, *) "How many volume-domain you want to generate?"
        read(*, *) N
        !allocate the memory to the allocatable arrays.
        allocate(A(N+2))
        allocate(B(N+2))
        allocate(C(N+2))
        allocate(P(N+2))
        allocate(Q(N+2))
        allocate(NodeGroup(N+2))
!QUICK NEED
        allocate(SurfaceGroup(N+1))
        allocate(MATRIX_QUICK(N, N))
        allocate(B_QUICK(N))
        allocate(x(N))
!QUICK END
        !begin to generator the grid
        call Grid(NodeGroup, SurfaceGroup, N, length)
        !print the grid message
        call PrintMessage(NodeGroup, SurfaceGroup)
        !set the first kind boundary condition
        write(*, *) "Please input the left node temperature:"
        read(*, *) NodeGroup(1)%temperature
        write(*, *) "Please input the right node temperature:"
        read(*, *) NodeGroup(N+2)%temperature
        !begin to set the property.
        call Property(NodeGroup, SurfaceGroup)
!****************************************************************************
!
! ����QUICK��ʽ�ļ��㷽����������ʽ�ļ��㷽����ͬ��������Ҫ�������д���
!
!****************************************************************************
!DEC$ DEFINE _QUICK_SCHEME_
!DEC$ IF DEFINED(_QUICK_SCHEME_)
        !�ֽ�QUICK��ʽ��ϵ������ֵΪ0��Ȼ���ٽ��м���
        MATRIX_QUICK = 0
        call GenerateModulusInQUICK(MATRIX_QUICK, B_QUICK, SurfaceGroup, NodeGroup(1)%temperature, NodeGroup(N+2)%temperature)
        call GaussMethod(MATRIX_QUICK, B_QUICK, x)
        !��x��ֵ���ڵ�ṹ���е��¶�
        do i=1, N
            NodeGroup(i+1)%temperature = x(i)
        end do
        deallocate(MATRIX_QUICK)
        deallocate(B_QUICK)
        deallocate(x)
        goto 1000  !ֱ����ת������д�ļ�������
!DEC$ ENDIF
!****************************************************************************
! ʹ�ò�ͬ��ʽ����ɢ����ʱ��ֻ��Ҫ���������GenerateModulusIn***�ӳ��򼴿�
!****************************************************************************
        call GenerateModulusInHS(C, A, B, SurfaceGroup)
        P(:) = 0.D0
        Q(:) = 0.D0
        write(*, *) "Fluid flow direction is on the x-axis positive direction?"
        read(*, *) v_direction
        !begin to solve the matrix P and Q
        call SolvePQ(P, Q, A, B, C, NodeGroup(1)%temperature, NodeGroup(N+2)%temperature, v_direction)
        !begin to solve the T
        call SolveT(P, Q, NodeGroup)
1000    write(*, *) "Temperature:", (NodeGroup(i)%temperature, i=1, N+2)
        !check the file status
        inquire(file=filename, exist=alive)
        if(alive) then
            write(*, *) "The temperature data file is ready, updating the data now...."
        else
            write(*, *) "The temperature data file not ready, writing the data now...."
        end if
        !begin to write the data
        open(unit=fileid, file=filename)
        do i=1, N+2
            write(fileid, *) NodeGroup(i)%temperature
        end do
        close(fileid)
        !release the memory which has benn allocated.
        deallocate(A)
        deallocate(B)
        deallocate(C)
        deallocate(P)
        deallocate(Q)
        deallocate(NodeGroup)
        deallocate(SurfaceGroup)
    end program
    