; Keep the original UniBIOS binary and font. Only its breakpoint frame read
; and stack-unwind entry change; all native entry points remain at their
; original addresses. UniAS recomputes the original checksum before the font.
    include MONLAYOUT.INC
    org $c000
    include MONPREFIX.INC
    tsx
    ldx 9,x
    include MONBODY.INC
    jmp paged_breakpoint_return
    include MONTEXT.INC
    checksum
    include MONFONT.INC
    end
