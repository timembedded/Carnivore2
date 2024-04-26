;--- Original Flash definitions
;Det00cp:equ	#20		; Manufacturer code
;Det02cp:equ	#7E		; Device Code C1
;Det1Cc1:equ	#0c		; Device Code C2  #0C -> M29W640GH / M29W640GL
;Det1Cc2:equ	#10		; Device Code C2  #10 -> M29W640GT / M29W640GB
;Det1Ec1:equ	#01		; Device Code C3  #01 -> M29W640GH / M29W640GT
;Det1Ec2:equ	#00		; Device Code C3  #00 -> M29W640GL / M29W640GB
;Det06cp:equ	#80		; Extended Memory Block Verify Code

;--- Flash definitions for MX29LV640ET
Det00cp:equ	#C2		; Manufacturer code
Det02cp:equ	#C9		; Device Code C1
Det1Cc1:equ	#FF		; Device Code C2  #0C -> M29W640GH / M29W640GL
Det1Cc2:equ	#00		; Device Code C2  #10 -> M29W640GT / M29W640GB
Det1Ec1:equ	#08		; Device Code C3  #01 -> M29W640GH / M29W640GT
Det1Ec2:equ	#FF		; Device Code C3  #00 -> M29W640GL / M29W640GB
Det06cp:equ	#08		; Extended Memory Block Verify Code
