//------------------------------------------------------------------------------
//  Copyright (c) 2011-2022 Anlogic, Inc.
//  All Right Reserved.
//------------------------------------------------------------------------------

////////////////////////////////////////////////////////////////////////////////
//
//  Vendor      : Anlogic
//  Version     : 0.1
//  Description : Anlogic Functional Simulation Model for Logic IP
//                PH1P_LOGIC_BUF               
//  Filename    : ph1p_logic_buf.v
//
////////////////////////////////////////////////////////////////////////////////
//
//  Revision    :
//  2022-10-26 - 0.1 - GS.JI - Initial version.
//
///////////////////////////////////////////////////////////////////////////////

`timescale  1ps/1ps

module  PH1P_LOGIC_BUF(
  o,
  i
);                  // user instantiated logic BUF

output o;           // [Template: Buffer input port.]
input i;            // [Template: Buffer output port.]

  buf lbuf (o, i);

endmodule
