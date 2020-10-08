    !���ߣ����ǹ�
    !��֯��Xi`an Jiaotong University - NuTHeL
    !���ڣ�2020/9/30
    !������ֵ����ѧ��һά��ɢ���̵����ԽǾ�������㷨-TDMA�㷨ʵ�֡�
    !ע�⣺�����ҵ���⣬TDMA�㷨���ڲ�ͬ�ڵ����ϵ����֪����ֻ֪���߽���������صĵ��ƹ�ϵʽ��
    !      �������Ǽ�ʹд�������ԽǾ��������Ԫ��Ҳ��δ֪�ģ��ʲ���ֱ��ʹ�þ��������б任��
    !      �����о�����Ԫ�����������������Ͽν��ĵ��ƹ�ϵʽ�����ǿ������ó�ʼ�������������Ľڵ�
    !      �����е��ƣ�����������δ֪���ϵ������ʱ���Խ��и�˹��Ԫ���߽�һ�����õ��ƹ�ϵʽ����ø����ڵ���¶�T��
    !�޸ģ�2020��10��5�գ���һά��̬�������������Ļ��ֽ����˸�����
    !      ʹ������������ɢ����B������Ҫ��
    !
    !****************************************************************
    !һά��̬���������ʼ��������ģ�飨������ɢ����B����������
    !�����Է���
    !****************************************************************
    !
    module SETUP
    implicit none
        !������dx��ָ���������ľ���
        private delta_x !����Ϊ˽�б���
        real*8 :: delta_x
        !��������һά��̬���񻮷֣�ʹ�õѿ�������ϵ������Ϊ�������񣬷���Ϊ�����������-FVM(Finite Volume Method)
        !����һ���ڵ�ṹ��
        type :: Node
            real*8 :: x             !�ڵ�����
            real*8 :: temperature   !�ڵ��¶�
            real*8 :: lambda        !�ڵ㴦�ĵ���ϵ��
        end type
        !����һ������ṹ��
        type :: Surface             !����interface��Fortran�еĹؼ��֣����Բ���surface����ʾ����
            real*8 :: x             !��������
            real*8 :: lambda        !���洦�ĵ�������ϵ��
        end type
    contains
        !��ʼ��һά������л���
        !2020/10/5����һά���񻮷ֽ���������ʹ�����������ɢ����B������Ҫ��
        subroutine Grid(NodeGroup, SurfaceGroup, N, length)
        implicit none
            type(Node), intent(inout)    :: NodeGroup(:)              !���ڴ洢�ڵ������
            type(Surface), intent(inout) :: SurfaceGroup(:)           !���ڴ洢���������
            integer, intent(in)          :: N                         !Ҫ���л��ֵĿ����������Ŀ
            real*8, intent(in)           :: length                    !����߽�����峤��
            integer                      :: i                         
            integer, parameter           :: fileid = 10               !�ļ�ID
            character(len=20)            :: filename='location.txt'   !�ļ���
            logical                      :: alive
            delta_x = length / N
            !����������Ŀ��������Ŀ���ڵ���Ŀ֮��Ĺ�ϵ�����ε���һ
            !��������������л��֣���¼�ڵ��������������
            !�ȶԽ�����л���
            SurfaceGroup(1)%x = 0
            do i=1, N
                SurfaceGroup(i+1)%x = SurfaceGroup(i)%x + delta_x
            end do
            !�������껮����Ϻ��ٶԽڵ�������л��֣�
            !��������ɢ����B�У��ڵ��������߽紦�ںͽ���������ͬ�⣬��������������������λ��
            NodeGroup(1)%x = SurfaceGroup(1)%x
            NodeGroup(N+2)%x = SurfaceGroup(N+1)%x
            do i=1, N
                NodeGroup(i+1)%x = (SurfaceGroup(i)%x+SurfaceGroup(i+1)%x) / 2.D0
            end do
            !����ļ�״̬
            inquire(file=filename, exist=alive)
            if(alive) then
                write(*, *) "����״̬�ļ��Ѿ����ڣ������¸����ļ�����...."
            else
                write(*, *) "����״̬�ļ������ڣ��ֿ�ʼ�����ļ�...."
            end if
            !��ʼд���ļ�
            open(unit=fileid, file=filename)
            write(fileid, *) "�ڵ����꣺    �������꣺"
            do i=1, N+1
                write(fileid, "(F8.4, 8X, F8.4)") NodeGroup(i)%x, SurfaceGroup(i)%x
            end do
            write(fileid, "(F8.4, 8X, F8.4)") NodeGroup(N+2)%x
            close(fileid)
            return
        end subroutine
        !��ʼ������ͽڵ㴦�����Խ��и�ֵ�����
        subroutine Property(NodeGroup, SurfaceGroup)
        implicit none
            type(Node), intent(inout)    :: NodeGroup(:)   
            type(Surface), intent(inout) :: SurfaceGroup(:)
            integer                      :: N          !���ڼ�¼�ڵ�ĸ���
            integer                      :: i
            real*8                       :: const_lambda              !�����Եĵ���ϵ��
            logical                      :: IsConstant !�����ж��û��ĵ���ϵ���Ƿ�Ϊ����
            logical                      :: alive
            integer, parameter           :: fileid=10  !�ļ�ID
            character(len=20)            :: filename='property.txt'
            N = size(NodeGroup, 1)       !�ڵ����
            write(*, *)"�������У�����ϵ���Ƿ�Ϊ������"
            read(*, *) IsConstant
            if(IsConstant == .true.) then
                goto 1001
            end if
            !
            !����TDMA�ڵ�һ��߽��������Ǵӵڶ����ڵ㵽�����ڶ����ڵ�֮���������ģ�
            !����ֻ��Ҫ��NodeGroup�ĵڶ����ڵ��뵹���ڶ����ڵ�֮����и�����ֵ����
            !ͬ������������߽紦�Ľ���Ҳ���ÿ��Ǹ�����ֵ��
            !��Ϊֻ���������ſ���ʹ���γ����ԽǾ�����ʹ��TDMA�㷨������⡣
            !
            !���û���ʼ����ڵ㴦�ĵ���ϵ��
            write(*, *)"������ڵ㴦�ĵ���ϵ��:"
            do i=1, N
                write(*, *) NodeGroup(i)%lambda
            end do
            !��ʼ���������洦�ĵ�������ϵ����
            !ʹ�õ���ƽ�����������洦�ĵ���ϵ��
            do i=1, N-1
                SurfaceGroup(i)%lambda = 2*NodeGroup(i)%lambda*NodeGroup(i+1)%lambda/ &
                                         (NodeGroup(i)%lambda+NodeGroup(i+1)%lambda)
            end do
            goto 1002
1001        write(*, *)"�����볣���Եĵ���ϵ����"
            read(*, *) const_lambda
            do i=1, N-1
                NodeGroup(i)%lambda = const_lambda
                SurfaceGroup(i)%lambda = const_lambda
            end do
            NodeGroup(N)%lambda = const_lambda
            !�������ڶ����ڵ㸳����ϵ��
            NodeGroup(N-1)%lambda = const_lambda
            !����ļ�״̬
1002        inquire(file=filename, exist=alive)
            if(alive) then
                write(*, *) "����״̬�ļ��Ѿ����ڣ������¸����ļ�����...."
            else
                write(*, *) "����״̬�ļ������ڣ��ֿ�ʼ�����ļ�...."
            end if
            !��ʼд���ļ�
            open(unit=fileid, file=filename)
            write(fileid, *) "�ڵ㵼���ʣ�  ���浼���ʣ�"
            do i=1, N-1
                write(fileid, "(F8.4,8X,F8.4)") NodeGroup(i)%lambda, SurfaceGroup(i)%lambda
            end do
            write(fileid, "(F8.4)") NodeGroup(N)%lambda
            close(fileid)
            return 
        end subroutine
        !
        !TODO:��Ӧ�����ҵ���ϵ�����¶ȵĹ�ϵʽ��Ȼ��ͨ��������ȷ��lambda��˲̬�����£��ϸ��ӣ���Ҫ������
        !
        !��Ȼ��Ҫע����ǣ�TDMA����Ԫ����������������ڵ�2���ڵ㵽������2���ڵ�֮����ɵģ�
        !��Ϊֻ��������һά��̬���̵ľ���ſ��������ԽǾ���
        !ͬʱ����1���ڵ������1���ڵ���������ṩ��һ��߽������������ɵڶ����ڵ㵽�����ڶ����ڵ��ϵ��,
        !�ɴ������ϵ������
        !
        !=============================================================================
        !��ʱ������ͽڵ�������Լ������Բ��������������,                              
        !��������Ҫ������ɢ��ɵĹ�ʽ���Ը����ڵ��ϵ��¶Ƚ�����⡣                     
        !=============================================================================
        !ͨ��������Ϣ����ͳһ��ʽ��aP*TP = aE*TE + aW*TW + b ��aP��aE��aW�Լ�b
        !����A������AE��AW��aP��AP��ʾ
        !���ɵ����ԽǾ���ʾ��ͼ��
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
        !ע�⣺aw1=0��aen=0��Ϊ�߽��������������ԽǾ�����û��д�룬
        !ͬʱ���������ԽǾ���Ҳ����Ҳ���ϼ��㷽���ϵ����ԽǾ�����ʽ��
        !ע���ʱAE,AP,AW,b��Ԫ�ظ���Ӧ����ڵ��Ԫ�ظ�����ͬ����������ʱ���򲻻��õ���ô���Ԫ�ء�
        !
        subroutine GenerateModulus(AE, AP, AW, b, SurfaceGroup, Source)
        implicit none
            real*8, intent(inout)       :: AE(:)
            real*8, intent(inout)       :: AW(:)
            real*8, intent(inout)       :: AP(:)
            real*8, intent(inout)       :: b(:)
            real*8, intent(in)          :: Source     !����Դ�����Ϊ�˼����⣬������Դ�趨Ϊ����
            type(Surface), intent(in)   :: SurfaceGroup(:)
            integer                     :: N          !��¼�������
            integer                     :: i
            logical                     :: alive
            character(len=20)           :: filename='COEFF.txt'
            integer, parameter          :: fileid = 10
            !���ǲ���Ҫ�ͱ߽��غϵĽ��棬�������ǽ�N����Ϊsize(SurfaceGroup, 1) - 1
            N = size(SurfaceGroup, 1)
            !����AW��Ϣ
            AW(1) = 0                                 !�߽�����
            do i=2, N+1
                AW(i) = SurfaceGroup(i-1)%lambda / delta_x
            end do
            !����AE��Ϣ
            AE(N+1) = 0                                 !�߽�����
            do i=1, N
                AE(i) = SurfaceGroup(i)%lambda / delta_x
            end do
            !
            !TODO:AP��Դǿ�йأ���Ҫ��һ�����ۣ�����Ϊ�˼����⣬������Դ�趨Ϊ����
            !
            !Fortran���õ���������
            AP = AE + AW          !������Ҫ�ڼ�ȥSpApdx������Ĭ������ԴΪ�㶨Դǿ������Sp=0
            b = Source*delta_x
            !ȫ������������ϣ����濪ʼд���ļ���
            !����ļ�״̬
            inquire(file=filename, exist=alive)
            if(alive) then
                write(*, *)"ͳһ���̸���ϵ���ļ��Ѿ����ڣ���������д������..."
            else
                write(*, *)"ͳһ���̸��������ļ������ڣ����ڴ���..."
            end if
            open(unit=fileid, file=filename)
            write(fileid, *) "lambda:     AW           AP               AE                 b"
            do i=1, N+1
                write(fileid, "(12X,F8.4,8X,F8.4,8X,F8.4,8X,F8.4)") AW(i), AP(i), AE(i), b(i)
            end do
            close(fileid)
            return
        end subroutine
        !��ӡ�ڵ�ͽ����һЩ��Ϣ
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
            !TODO:��ӡ�������Ϣ
            return
        end subroutine
    end module
    !****************************************************************
    !TDMA���ģ��
    !****************************************************************
    module TDMA
    use SETUP
    implicit none
    contains
        !�����P��Q�����P��Q�Ժ����ǾͿ������ø�˹��Ԫ�����������õ��������T��
        !��TDMA������ӵ�һ��߽���������������һ���ڵ���¶�t1�����һ���ڵ���¶�tm1
        subroutine SolvePQ(P, Q, A, B, C, D, t1, tm1)
        implicit none
            real*8, intent(inout) :: P(:)
            real*8, intent(inout) :: Q(:)
            real*8, intent(in)    :: A(:)           !Tiǰϵ��
            real*8, intent(in)    :: B(:)           !Ti+1ǰϵ��
            real*8, intent(in)    :: C(:)           !Ti-1ǰϵ��
            real*8, intent(in)    :: D(:)
            real*8, intent(in)    :: t1
            real*8, intent(in)    :: tm1
            real*8                :: coeff = 0.D0   !��¼�м�ϵ��
            integer               :: i
            integer               :: fileid=10
            character(len=20)     :: filename='PQ.txt'
            integer               :: length         !��¼A,B,C,D,P,Q����ĳ��ȣ�Ҳ������Ҫ�����ڲ��ڵ�ĸ���
            length = size(A, 1)
            !�������ݵ�һ��߽������������P1��Q1
            P(1) = 0
            Q(1) = t1
            !���濪ʼ���е������������P��Q
            !ʹ���˵�һ��߽�������������Ԫ���̴ӵڶ����ڵ㿪ʼ
            do i=2, length
                coeff = A(i)-C(i)*P(i-1)
                P(i) = B(i) / coeff
                Q(i) = (D(i)+C(i)*Q(i-1)) / coeff
            end do
            !��ʼд�ļ�
            open(unit=fileid, file=filename)
            write(fileid, *) "P         Q"
            do i=1, length
                write(fileid, "(F8.4, 8X, F8.4)") P(i), Q(i)
            end do
            close(fileid)
            return
        end subroutine
        !���P��Q֮�󣬽�������ʼ���лش����������ڵ���¶�
        subroutine SolveT(P, Q, NodeGroup)
        implicit none
            real*8, intent(inout)        :: P(:)
            real*8, intent(inout)        :: Q(:)
            type(Node), intent(inout)    :: NodeGroup(:)
            integer                      :: length
            integer                      :: i
            length = size(NodeGroup, 1)
            !��ʼ�Ӻ���ǰ���лش�����¶�
            !�ش������Ǵӵ����ڶ����ڵ㵽�ڶ����ڵ�
            !�������ڶ����ڵ���¶�
            NodeGroup(length-1)%temperature = Q(length-1)
            do i=length-2, 2, -1
                NodeGroup(i)%temperature = P(i)*NodeGroup(i+1)%temperature + Q(i)
            end do
            return
        end subroutine
    end module
    !��ʼ������
    program main
    use SETUP
    use TDMA
    implicit none
        real*8                    :: Source !Դ��
        real*8                    :: Length !����ĳ���
        real*8, allocatable       :: A(:)
        real*8, allocatable       :: B(:)
        real*8, allocatable       :: C(:)
        real*8, allocatable       :: D(:)
        real*8, allocatable       :: P(:)
        real*8, allocatable       :: Q(:)
        type(Node), allocatable   :: NodeGroup(:)
        type(Surface),allocatable :: SurfaceGroup(:)
        integer                   :: i
        integer                   :: N    !��¼����ռ�Ĵ�С
        integer, parameter        :: fileid = 10
        logical                   :: alive
        character(len=20)         :: filename = 'temperature.csv'
        write(*, *) "����������������ĳ���:"
        read(*, *) Length
        write(*, *) "�����뻮�ֵĿ�������ĸ�����"
        read(*, *) N
        !�����ڴ�ռ�
        allocate(A(N+2))
        allocate(B(N+2))
        allocate(C(N+2))
        allocate(D(N+2))
        allocate(P(N+2))
        allocate(Q(N+2))
        allocate(NodeGroup(N+2))
        allocate(SurfaceGroup(N+1))
        !��ʼ��������
        call Grid(NodeGroup, SurfaceGroup, N, Length)
        !��ӡ������Ϣ
        call PrintMessage(NodeGroup, SurfaceGroup)
!DEBUG�µ���������
!!DEC$ DEFINE __DEBUG__
!DEC$ IF DEFINED(__DEBUG__)
        !��������鸳��ֵ��
        !�߽�������C(1)=0��B(10)=0
        write(*, *) "������Ti ���ϵ����"
        read(*, *) A(:)
        write(*, *) "������Ti+1���ϵ��:"
        read(*, *) B(:)
        write(*, *) "������Ti-1���ϵ��:"
        read(*, *) C(:)
        !�����һά����������û������Դ��������DΪ0
        !D = 0.D0
        write(*, *) "�����볣����D��"
        read(*, *) D(:)
!DEC$ ENDIF
        !���õ�һ��߽�����
        write(*, *)"�������һ���ڵ���¶�:"
        read(*, *) NodeGroup(1)%temperature
        write(*, *)"���������һ���ڵ���¶�"
        read(*, *) NodeGroup(N+2)%temperature
        !��ʼ��������
        call Property(NodeGroup, SurfaceGroup)
        write(*, *)"������Դ�"
        read(*, *) Source
        call GenerateModulus(C, A, B, D, SurfaceGroup, Source)
        !��P,Q�����ʼֵȫ����ֵΪ0
        P(:) = 0.D0
        Q(:) = 0.D0
        !��ʼ����ϵ��P��Q�����
        call SolvePQ(P, Q, A, B, C, D, NodeGroup(1)%temperature, NodeGroup(N+2)%temperature)
        !��ʼ����T�����
        call SolveT(P, Q, NodeGroup)
        write(*, *)"�¶ȵĽ��Ϊ:", (NodeGroup(i)%temperature, i=1, N+2)
        !����ļ�״̬
        inquire(file=filename, exist=alive)
        if(alive) then
            write(*, *) "�¶������ļ��Ѿ����ڣ�������д�����ݽ��и���...."
        else
            write(*, *) "�¶������ļ������ڣ��ֿ�ʼд������....."
        end if
        !��ʼд������
        open(unit=fileid, file=filename)
        do i=1, N+2
            write(fileid, *) NodeGroup(i)%temperature
        end do
        !�ر��ļ�
        close(fileid)
        !�ͷ��ڴ�
        deallocate(A)
        deallocate(B)
        deallocate(C)
        deallocate(D)
        deallocate(P)
        deallocate(Q)
        deallocate(NodeGroup)
        deallocate(SurfaceGroup)
    end program
    