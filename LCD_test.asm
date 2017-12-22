
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
CNT1		EQU		0x20	;遅延カウント用１
CNT2		EQU		0x21	;遅延カウント用２
TMP_DATA	EQU		0x22	;文字コード保存用
TMP_DATA_B	EQU		0x23	;dusyチェック用
TMP_CNT		EQU		0x24	;何文字目をとるか
CCNT		EQU		0x25	;文字数
LCNT		EQU		0x26	;行番号

#define		LCD_DATA	PORTA
#define		LCD_DDIR	TRISA
#define		LCD_RS		PORTB,5
#define		LCD_RW		PORTB,6
#define		LCD_E		PORTB,7
#define		BUSY_BIT	3

#define		ROWS		d'16'	;横方向16文字

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
	bcf		STATUS,RP1	;バンク０

	clrf	INTCON		;割り込み禁止
	clrf	PORTA		;すべて出力０
	movlw	0x07
	movwf	CMCON		;コンパレータ不使用

	bsf		STATUS,RP0	;バンク１

	bsf		PCON,OSCF	;内部クロック４MHｚ
	movlw	B'00010110'
	movwf	TRISB		;RB０、RB5～RB７出力
	clrf	LCD_DDIR	;RAすべて出力

	bcf		STATUS,RP0	;バンク０

	bcf		LCD_RS
	bcf		LCD_RW		;信号０
	bcf		LCD_E
	clrf	LCD_DATA	;

main_loop
	call	dly_10m
	call	lcd_init	;LCD初期化
	call	dly_10m

	movlw	b'00001110'	;カーソルオフ、－＞方向
	call	cmd_send
	
	call	dly_10m
	clrf	CCNT
	clrf	LCNT
	clrf	TMP_CNT
str_out1
	movf	TMP_CNT,w	;何個目？
	call	INIT_MSG	;１文字取ってくる
	addlw	0x00
	
	btfsc	STATUS,Z	;０？
	goto	stop		;はい－＞stop
	call	chr_out		;文字出力
	incf	TMP_CNT,f
	goto	str_out1		  ;loop forever, remove this instruction, for test only

stop
	bsf		PORTB,3
	goto	stop

chr_out
	call	data_send
	incf	CCNT,f		;表示したら１足す
	movlw	ROWS		;上限は１６文字
	subwf	CCNT,w		;引き算
	btfss	STATUS,Z	;０以外(Zが１)？
	goto	chr_done	;はいー＞そのまま帰る
	
	clrf	CCNT		;０文字目
	btfss	LCNT,0		;１行目(LCONが０)？
	goto	chr_ldl		;はいー＞２行目移行処理
	movlw	b'10000000'	;１行目移行
	call	cmd_send
	bcf		LCNT,0		;１行目だよ
	goto	chr_done
chr_ldl
	movlw	b'11000000'	;2行目移行
	call	cmd_send
	bsf		LCNT,0		;２行目だよ
chr_done
	return
	

data_send
	movwf	TMP_DATA
	swapf	TMP_DATA,w
	addlw	0x0f
	movwf	LCD_DATA	;上位４ビット出力
	bcf		LCD_RW
	bsf		LCD_RS		;データなので
	bsf		LCD_E
	bcf		LCD_E
	movf	TMP_DATA,w
	addlw	0x0f
	movwf	LCD_DATA	;下位４ビット出力
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
	movlw	b'00110000'	;初期化用データ１
	call	cmd_send4	;送る
	call	dly_10m
	movlw	b'00110000'	;初期化用データ２
	call	cmd_send4	;
	call	dly_100u
	movlw	b'00110000'	;初期化用データ３
	call	cmd_send4
	call	dly_100u
	movlw	b'00100000'	;４ビットモード
	call	cmd_send4
;ビジーチェック可能
	call	dly_100u
	call	busy_check

	movlw	b'00101000'	;初期モード
	call	cmd_send	

	movlw	b'00000001'	;LCDクリア
	call	cmd_send

	movlw	b'00000110'	;エントリモード
	call	cmd_send
	return



;初期化用コマンド４ビット送信
cmd_send4
	movwf	TMP_DATA
	swapf	TMP_DATA,W	;入れ替え
	andlw	0x0f		;マスクする
	movwf	LCD_DATA
	bcf		LCD_RW
	bcf		LCD_RS
	bsf		LCD_E
	bcf		LCD_E

	return

;ビジーチェック
busy_check
	bsf		STATUS,RP0	;バンク１
	movlw	0xff
	movwf	LCD_DDIR	;ポートAすべて入力
	bcf		STATUS,RP0	;バンク０
busy1
	bcf		LCD_RS
	bsf		LCD_RW		;読み込み
	bsf		LCD_E
	nop
	movf	LCD_DATA,w
	andlw	0x0f		;下位４ビットのみ取り出し
	movwf	TMP_DATA_B
	bcf		LCD_E
	nop
	bsf		LCD_E
	nop
	bcf		LCD_E
	btfsc	TMP_DATA_B,BUSY_BIT		;TMP_DATAの３ビット目が１か？
	goto	busy1		;はい－＞繰り返し
	bcf		LCD_RW		;
	bsf		STATUS,RP0	;バンク１
	movlw	0x00
	movwf	LCD_DDIR	;ポートAすべて出力
	bcf		STATUS,RP0	;バンク０
	return

;LCDへコマンドを送る
cmd_send
	movwf	TMP_DATA
	swapf	TMP_DATA,w	;4ビット入れ替え
	andlw	0X0f		;下位４ビットのみ
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

