onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /ascon_core/clk
add wave -noupdate /ascon_core/rst_n
add wave -noupdate -divider config
add wave -noupdate /ascon_core/start_i
add wave -noupdate /ascon_core/decrypt_i
add wave -noupdate -radix unsigned /ascon_core/ad_size_i
add wave -noupdate -radix unsigned /ascon_core/di_size_i
add wave -noupdate -radix unsigned /ascon_core/delay_i
add wave -noupdate /ascon_core/key_i
add wave -noupdate /ascon_core/nonce_i
add wave -noupdate -divider {size decoder}
add wave -noupdate -radix unsigned /ascon_core/u_ascon_size_decoder/ad_pad_idx_o
add wave -noupdate -radix unsigned /ascon_core/u_ascon_size_decoder/di_pad_idx_o
add wave -noupdate -radix unsigned /ascon_core/u_ascon_size_decoder/ad_blk_no_o
add wave -noupdate -radix unsigned /ascon_core/u_ascon_size_decoder/di_blk_no_o
add wave -noupdate -divider data
add wave -noupdate /ascon_core/data_i
add wave -noupdate /ascon_core/data_valid_i
add wave -noupdate /ascon_core/data_ready_o
add wave -noupdate /ascon_core/data_o
add wave -noupdate /ascon_core/data_valid_o
add wave -noupdate /ascon_core/tag_o
add wave -noupdate /ascon_core/tag_valid_o
add wave -noupdate -divider status
add wave -noupdate /ascon_core/idle_o
add wave -noupdate /ascon_core/sync_o
add wave -noupdate /ascon_core/done_o
add wave -noupdate -divider controller
add wave -noupdate /ascon_core/u_ascon_ctrl/phase_q
add wave -noupdate /ascon_core/u_ascon_ctrl/op_o
add wave -noupdate /ascon_core/u_ascon_ctrl/en_state_o
add wave -noupdate /ascon_core/u_ascon_ctrl/sel_ad_o
add wave -noupdate /ascon_core/u_ascon_ctrl/en_padding_o
add wave -noupdate /ascon_core/u_ascon_ctrl/en_trunc_o
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {897340 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
configure wave -valuecolwidth 121
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ps} {1701001 ps}
