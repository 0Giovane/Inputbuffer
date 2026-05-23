transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -vlog01compat -work work +incdir+F:/Teste_32bits {F:/Teste_32bits/Input_Buffer.v}
vcom -93 -work work {F:/Teste_32bits/memoria.vhd}

