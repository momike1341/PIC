
;**********************************************************************
;   This file is a basic code template for assembly code generation   *
;   on the PIC16F628A. This file contains the basic code              *
;   building blocks to build upon.                                    *
;                                                                     *
;   Refer to the MPASM User's Guide for additional information on     *
;   features of the assembler (Document DS33014).                     *
;                                                                     *
;   Refer to the respective PIC data sheet for additional             *
;   information on the instruction set.                               *
;                                                                     *
;**********************************************************************
;                                                                     *
;    Filename:	    xxx.asm                                           *
;    Date:                                                            *
;    File Version:                                                    *
;                                                                     *
;    Author:                                                          *
;    Company:                                                         *
;                                                                     *
;                                                                     *
;**********************************************************************
;                                                                     *
;    Files Required: P16F628A.INC                                     *
;                                                                     *
;**********************************************************************
;                                                                     *
;    Notes:                                                           *
;                                                                     *
;**********************************************************************

	list      p=16f628A           ; list directive to define processor
	#include <p16F628A.inc>       ; processor specific variable definitions

	errorlevel  -302              ; suppress message 302 from list file

	__CONFIG   _CP_OFF  & _LVP_OFF & _BOREN_ON & _MCLRE_OFF & _WDT_OFF & _PWRTE_ON & _INTRC_OSC_NOCLKOUT 

; '__CONFIG' directive is used to embed configuration word within .asm file.
; The lables following the directive are located in the respective .inc file.
; See data sheet for additional information on configuration word settings.





;***** VARIABLE DEFINITIONS
w_temp        EQU     0x7E        ; variable used for context saving 
status_temp   EQU     0x7F        ; variable used for context saving
CNT1		EQU		0x20	;�x���J�E���g�p�P
CNT2		EQU		0x21	;�x���J�E���g�p�Q
TMP_DATA	EQU		0x22	;�����R�[�h�ۑ��p
TMP_DATA_B	EQU		0x23	;dusy�`�F�b�N�p
TMP_CNT		EQU		0x24	;�������ڂ��Ƃ邩
CCNT		EQU		0x25	;������
LCNT		EQU		0x26	;�s�ԍ�

#define		LCD_DATA	PORTA
#define		LCD_DDIR	TRISA
#define		LCD_RS		PORTB,5
#define		LCD_RW		PORTB,6
#define		LCD_E		PORTB,7
#define		BUSY_BIT	3

#define		ROWS		d'16'	;������16����

;**********************************************************************
	ORG     0x000             ; processor reset vector
	goto    main              ; go to beginning of program
	

	ORG     0x004             ; interrupt vector location
	movwf   w_temp            ; save off current W register contents
	movf	STATUS,w          ; move status register into W register
	movwf	status_temp       ; save off contents of STATUS register

; isr code can go here or be located as a call subroutine elsewhere


	movf    status_temp,w     ; retrieve copy of STATUS register
	movwf	STATUS            ; restore pre-isr STATUS register contents
	swapf   w_temp,f
	swapf   w_temp,w          ; restore pre-isr W register contents
	retfie                    ; return from interrupt


main

; remaining code goes here

	bcf		STATUS,RP0
	bcf		STATUS,RP1	;�o���N�O

	clrf	INTCON		;���荞�݋֎~
	clrf	PORTA		;���ׂďo�͂O
	movlw	0x07
	movwf	CMCON		;�R���p���[�^�s�g�p

	bsf		STATUS,RP0	;�o���N�P

	bsf		PCON,OSCF	;�����N���b�N�SMH��
	movlw	B'00010110'
	movwf	TRISB		;RB�O�ARB5�`RB�V�o��
	clrf	LCD_DDIR	;RA���ׂďo��

	bcf		STATUS,RP0	;�o���N�O

	bcf		LCD_RS
	bcf		LCD_RW		;�M���O
	bcf		LCD_E
	clrf	LCD_DATA	;

main_loop
	call	dly_10m
	call	lcd_init	;LCD������
	call	dly_10m

	movlw	b'00001110'	;�J�[�\���I�t�A�|������
	call	cmd_send
	
	call	dly_10m
	clrf	CCNT
	clrf	LCNT
	clrf	TMP_CNT
str_out1
	movf	TMP_CNT,w	;���ځH
	call	INIT_MSG	;�P��������Ă���
	addlw	0x00
	
	btfsc	STATUS,Z	;�O�H
	goto	stop		;�͂��|��stop
	call	chr_out		;�����o��
	incf	TMP_CNT,f
	goto	str_out1		  ;loop forever, remove this instruction, for test only

stop
	bsf		PORTB,3
	goto	stop

chr_out
	call	data_send
	incf	CCNT,f		;�\��������P����
	movlw	ROWS		;����͂P�U����
	subwf	CCNT,w		;�����Z
	btfss	STATUS,Z	;�O�ȊO(Z���P)�H
	goto	chr_done	;�͂��[�����̂܂܋A��
	
	clrf	CCNT		;�O������
	btfss	LCNT,0		;�P�s��(LCON���O)�H
	goto	chr_ldl		;�͂��[���Q�s�ڈڍs����
	movlw	b'10000000'	;�P�s�ڈڍs
	call	cmd_send
	bcf		LCNT,0		;�P�s�ڂ���
	goto	chr_done
chr_ldl
	movlw	b'11000000'	;2�s�ڈڍs
	call	cmd_send
	bsf		LCNT,0		;�Q�s�ڂ���
chr_done
	return
	

data_send
	movwf	TMP_DATA
	swapf	TMP_DATA,w
	addlw	0x0f
	movwf	LCD_DATA	;��ʂS�r�b�g�o��
	bcf		LCD_RW
	bsf		LCD_RS		;�f�[�^�Ȃ̂�
	bsf		LCD_E
	bcf		LCD_E
	movf	TMP_DATA,w
	addlw	0x0f
	movwf	LCD_DATA	;���ʂS�r�b�g�o��
	bcf		LCD_RW
	bsf		LCD_RS
	bsf		LCD_E
	bcf		LCD_E
	call	busy_check
	return

; initialize eeprom locations


INIT_MSG
	addwf	PCL,1
	DT		"LCD TEST",0x00


lcd_init
	call	dly_10m
	call	dly_10m
	movlw	b'00110000'	;�������p�f�[�^�P
	call	cmd_send4	;����
	call	dly_10m
	movlw	b'00110000'	;�������p�f�[�^�Q
	call	cmd_send4	;
	call	dly_100u
	movlw	b'00110000'	;�������p�f�[�^�R
	call	cmd_send4
	call	dly_100u
	movlw	b'00100000'	;�S�r�b�g���[�h
	call	cmd_send4
;�r�W�[�`�F�b�N�\
	call	dly_100u
	call	busy_check

	movlw	b'00101000'	;�������[�h
	call	cmd_send	

	movlw	b'00000001'	;LCD�N���A
	call	cmd_send

	movlw	b'00000110'	;�G���g�����[�h
	call	cmd_send
	return



;�������p�R�}���h�S�r�b�g���M
cmd_send4
	movwf	TMP_DATA
	swapf	TMP_DATA,W	;����ւ�
	andlw	0x0f		;�}�X�N����
	movwf	LCD_DATA
	bcf		LCD_RW
	bcf		LCD_RS
	bsf		LCD_E
	bcf		LCD_E

	return

;�r�W�[�`�F�b�N
busy_check
	bsf		STATUS,RP0	;�o���N�P
	movlw	0xff
	movwf	LCD_DDIR	;�|�[�gA���ׂē���
	bcf		STATUS,RP0	;�o���N�O
busy1
	bcf		LCD_RS
	bsf		LCD_RW		;�ǂݍ���
	bsf		LCD_E
	nop
	movf	LCD_DATA,w
	andlw	0x0f		;���ʂS�r�b�g�̂ݎ��o��
	movwf	TMP_DATA_B
	bcf		LCD_E
	nop
	bsf		LCD_E
	nop
	bcf		LCD_E
	btfsc	TMP_DATA_B,BUSY_BIT		;TMP_DATA�̂R�r�b�g�ڂ��P���H
	goto	busy1		;�͂��|���J��Ԃ�
	bcf		LCD_RW		;
	bsf		STATUS,RP0	;�o���N�P
	movlw	0x00
	movwf	LCD_DDIR	;�|�[�gA���ׂďo��
	bcf		STATUS,RP0	;�o���N�O
	return

;LCD�փR�}���h�𑗂�
cmd_send
	movwf	TMP_DATA
	swapf	TMP_DATA,w	;4�r�b�g����ւ�
	andlw	0X0f		;���ʂS�r�b�g�̂�
	movwf	LCD_DATA
	bcf		LCD_RW
	bcf		LCD_RS
	bsf		LCD_E
	bcf		LCD_E
	movf	TMP_DATA,w
	andlw	0x0f
	movwf	LCD_DATA
	bcf		LCD_RW
	bcf		LCD_RS
	bsf		LCD_E
	bcf		LCD_E
	call	busy_check
	return


dly_100u
	movlw	0x32
	movwf	CNT1
dly_100u1
	decfsz	CNT1,f
	goto	dly_100u1
	return

dly_10m
	movlw	d'10'
	movwf	CNT1
dly_10m1
	call	dly_1m
	decfsz	CNT1,f
	goto	dly_10m1
	return

dly_1m
	movlw	d'200'
	movwf	CNT2
dly_1m1
	nop
	nop
	decfsz	CNT2,f
	goto	dly_1m1
	return

	ORG	0x2100
	DE	0x00, 0x01, 0x02, 0x03


	END                       ; directive 'end of program'

