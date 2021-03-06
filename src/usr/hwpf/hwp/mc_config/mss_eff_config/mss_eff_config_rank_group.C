/* IBM_PROLOG_BEGIN_TAG                                                   */
/* This is an automatically generated prolog.                             */
/*                                                                        */
/* $Source: src/usr/hwpf/hwp/mc_config/mss_eff_config/mss_eff_config_rank_group.C $ */
/*                                                                        */
/* OpenPOWER HostBoot Project                                             */
/*                                                                        */
/* Contributors Listed Below - COPYRIGHT 2012,2014                        */
/* [+] International Business Machines Corp.                              */
/*                                                                        */
/*                                                                        */
/* Licensed under the Apache License, Version 2.0 (the "License");        */
/* you may not use this file except in compliance with the License.       */
/* You may obtain a copy of the License at                                */
/*                                                                        */
/*     http://www.apache.org/licenses/LICENSE-2.0                         */
/*                                                                        */
/* Unless required by applicable law or agreed to in writing, software    */
/* distributed under the License is distributed on an "AS IS" BASIS,      */
/* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or        */
/* implied. See the License for the specific language governing           */
/* permissions and limitations under the License.                         */
/*                                                                        */
/* IBM_PROLOG_END_TAG                                                     */
// $Id: mss_eff_config_rank_group.C,v 1.12 2014/04/01 17:10:21 asaetow Exp $
// $Source: /afs/awd/projects/eclipz/KnowledgeBase/.cvsroot/eclipz/chips/centaur/working/procedures/ipl/fapi/mss_eff_config_rank_group.C,v $
//------------------------------------------------------------------------------
// *! (C) Copyright International Business Machines Corp. 2011
// *! All Rights Reserved -- Property of IBM
// *! ***  ***
//------------------------------------------------------------------------------
// *! TITLE       : mss_eff_config_rank_group
// *! DESCRIPTION : see additional comments below
// *! OWNER NAME  : Anuwat Saetow     Email: asaetow@us.ibm.com
// *! BACKUP NAME : Mark Bellows      Email: bellows@us.ibm.com
// *! ADDITIONAL COMMENTS :
//
// This procedure takes in attributes and determines proper rank groupings that will be apply to the system and used during draminit_training and draminit_training_adv. Each valid rank in the system will be assigned to one of twelve attributes below. Only the primary rank group will be calibrated and have values stored in the delay registers.
//    EFF_PRIMARY_RANK_GROUP0,    EFF_PRIMARY_RANK_GROUP1,    EFF_PRIMARY_RANK_GROUP2,    EFF_PRIMARY_RANK_GROUP3
//    EFF_SECONDARY_RANK_GROUP0,  EFF_SECONDARY_RANK_GROUP1,  EFF_SECONDARY_RANK_GROUP2,  EFF_SECONDARY_RANK_GROUP3
//    EFF_TERTIARY_RANK_GROUP0,   EFF_TERTIARY_RANK_GROUP1,   EFF_TERTIARY_RANK_GROUP2,   EFF_TERTIARY_RANK_GROUP3
//    EFF_QUATERNARY_RANK_GROUP0, EFF_QUATERNARY_RANK_GROUP1, EFF_QUATERNARY_RANK_GROUP2, EFF_QUATERNARY_RANK_GROUP3
//
//------------------------------------------------------------------------------
// Don't forget to create CVS comments when you check in your changes!
//------------------------------------------------------------------------------
// CHANGE HISTORY:
//------------------------------------------------------------------------------
// Version:|  Author: |  Date:  | Comment:
//---------|----------|---------|-----------------------------------------------
//   1.13  |          |         | 
//   1.12  | asaetow  |31-MAR-13| Added FFDC error callout from Andrea's FW RAS review. 
//         |          |         | NOTE: Do NOT pickup without memory_mss_eff_config_rank_group.xml v1.2 
//   1.11  | kcook    |16-AUG-13| Added LRDIMM support.
//   1.10  | asaetow  |17-APR-13| Removed 32G CDIMM 1R dualdrop workaround.
//         |          |         | NOTE: Needs mss_draminit_training.C v1.57 or newer.
//   1.9   | asaetow  |01-APR-13| Added 32G CDIMM 1R dualdrop workaround.
//         |          |         | NOTE: Normally primary_rank_group0=0, primary_rank_group1=4.
//   1.8   | asaetow  |29-AUG-12| Fixed variable init for rank_group to INVALID for PORT1. 
//   1.7   | asaetow  |24-AUG-12| Fixed variable init for rank_group to INVALID. 
//   1.6   | asaetow  |30-APR-12| Fixed "fapi::" for hostboot, added "const", renamed "i_target_mba", and changed comments.
//         |          |         | Changed message to standardized format.
//         |          |         | Changed BACKUP to Mark Bellows.
//   1.5   | asaetow  |20-MAR-12| Changed EFF_CONFIG_RANK_GROUP_RC_ERROR_001A to RC_MSS_PLACE_HOLDER_ERROR temporary until Cronus is ready to pick up error code xml. 
//   1.4   | asaetow  |08-FEB-12| Added INVALID(255) into ranks that do not exist.
//         |          |         | Removed support for mix ATTR_EFF_NUM_RANKS_PER_DIMM within a port.
//         |          |         | Changed "rc =" to "FAPI_SET_HWP_ERROR(rc, EFF_CONFIG_RANK_GROUP_RC_ERROR_001A)".
//   1.3   | asaetow  |24-JAN-12| Removed all temp hard code work around and enabled FAPI_ATTR_GET(). 
//         |          |         | Added mem_attr write back support, enabled FAPI_ATTR_SET().
//         |          |         | Removed triple-drop support.
//         |          |         | Changed PORT_SIZE and DIMM_SIZE to const 2 to match mem_attr. 
//         |          |         | Added extern "C" so that procedure can be run independently.
//   1.2   | asaetow  |03-NOV-11| Fixed to comply with mss_eff_config_rank_group.H
//   1.1   | asaetow  |01-NOV-11| First Draft.



//----------------------------------------------------------------------
//  My Includes
//----------------------------------------------------------------------



//----------------------------------------------------------------------
//  Includes
//----------------------------------------------------------------------
#include <fapi.H>



//----------------------------------------------------------------------
// ENUMs
//----------------------------------------------------------------------
enum {
   CDIMM = 0,
   RDIMM = 1,
   UDIMM = 2,
   LRDIMM = 3,
   INVALID = 255,
};



extern "C" {



//******************************************************************************
//* name=mss_eff_config_rank_group, param=i_target_mba, return=ReturnCode
//******************************************************************************
fapi::ReturnCode mss_eff_config_rank_group(const fapi::Target i_target_mba) {
   fapi::ReturnCode rc = fapi::FAPI_RC_SUCCESS;
   const char * const PROCEDURE_NAME = "mss_eff_config_rank_group";
   const fapi::Target& TARGET_MBA = i_target_mba;
   FAPI_INF("*** Running %s on %s ... ***", PROCEDURE_NAME, i_target_mba.toEcmdString());

   const uint8_t PORT_SIZE = 2;
   const uint8_t DIMM_SIZE = 2;
   // ATTR_EFF_DRAM_GEN: EMPTY = 0, DDR3 = 1, DDR4 = 2,
   // ATTR_EFF_DIMM_TYPE: CDIMM = 0, RDIMM = 1, UDIMM = 2, LRDIMM = 3,
   uint8_t num_ranks_per_dimm_u8array[PORT_SIZE][DIMM_SIZE];
   uint8_t dram_gen_u8;
   uint8_t dimm_type_u8;

   rc = FAPI_ATTR_GET(ATTR_EFF_NUM_RANKS_PER_DIMM, &i_target_mba, num_ranks_per_dimm_u8array); if(rc) return rc;
   rc = FAPI_ATTR_GET(ATTR_EFF_DRAM_GEN, &i_target_mba, dram_gen_u8); if(rc) return rc;
   rc = FAPI_ATTR_GET(ATTR_EFF_DIMM_TYPE, &i_target_mba, dimm_type_u8); if(rc) return rc;

   uint8_t primary_rank_group0_u8array[PORT_SIZE];
   uint8_t primary_rank_group1_u8array[PORT_SIZE];
   uint8_t primary_rank_group2_u8array[PORT_SIZE];
   uint8_t primary_rank_group3_u8array[PORT_SIZE];
   uint8_t secondary_rank_group0_u8array[PORT_SIZE];
   uint8_t secondary_rank_group1_u8array[PORT_SIZE];
   uint8_t secondary_rank_group2_u8array[PORT_SIZE];
   uint8_t secondary_rank_group3_u8array[PORT_SIZE];
   uint8_t tertiary_rank_group0_u8array[PORT_SIZE];
   uint8_t tertiary_rank_group1_u8array[PORT_SIZE];
   uint8_t tertiary_rank_group2_u8array[PORT_SIZE];
   uint8_t tertiary_rank_group3_u8array[PORT_SIZE];
   uint8_t quanternary_rank_group0_u8array[PORT_SIZE];
   uint8_t quanternary_rank_group1_u8array[PORT_SIZE];
   uint8_t quanternary_rank_group2_u8array[PORT_SIZE];
   uint8_t quanternary_rank_group3_u8array[PORT_SIZE];

   for (uint8_t cur_port = 0; cur_port < PORT_SIZE; cur_port += 1) {
      //Removed 32G CDIMM 1R dualdrop workaround.
      //NOTE: Needs mss_draminit_training.C v1.57 or newer.
      //if ((dimm_type_u8 == CDIMM) && (num_ranks_per_dimm_u8array[cur_port][0] == 1) && (num_ranks_per_dimm_u8array[cur_port][1] == 1)) {
         // NOTE: 32G CDIMM 1R dualdrop workaround, normally primary_rank_group0=0, primary_rank_group1=4.
         //primary_rank_group0_u8array[cur_port] = 0;
         //primary_rank_group1_u8array[cur_port] = INVALID;
         //primary_rank_group2_u8array[cur_port] = INVALID;
         //primary_rank_group3_u8array[cur_port] = INVALID;
         //secondary_rank_group0_u8array[cur_port] = 4;
         //secondary_rank_group1_u8array[cur_port] = INVALID;
         //secondary_rank_group2_u8array[cur_port] = INVALID;
         //secondary_rank_group3_u8array[cur_port] = INVALID;
         //tertiary_rank_group0_u8array[cur_port] = INVALID;
         //tertiary_rank_group1_u8array[cur_port] = INVALID;
         //tertiary_rank_group2_u8array[cur_port] = INVALID;
         //tertiary_rank_group3_u8array[cur_port] = INVALID;
         //quanternary_rank_group0_u8array[cur_port] = INVALID;
         //quanternary_rank_group1_u8array[cur_port] = INVALID;
         //quanternary_rank_group2_u8array[cur_port] = INVALID;
         //quanternary_rank_group3_u8array[cur_port] = INVALID;
      //} else if (dimm_type_u8 == LRDIMM) {
      if (dimm_type_u8 == LRDIMM) {
         primary_rank_group2_u8array[cur_port] = INVALID;
         secondary_rank_group2_u8array[cur_port] = INVALID;
         tertiary_rank_group2_u8array[cur_port] = INVALID;
         quanternary_rank_group2_u8array[cur_port] = INVALID;

         primary_rank_group3_u8array[cur_port] = INVALID;
         secondary_rank_group3_u8array[cur_port] = INVALID;
         tertiary_rank_group3_u8array[cur_port] = INVALID;
         quanternary_rank_group3_u8array[cur_port] = INVALID;

         // dimm 0 (far socket)
         switch (num_ranks_per_dimm_u8array[cur_port][0]) {
           case 4:               // 4 rank lrdimm
                 primary_rank_group0_u8array[cur_port] = 0;
                 secondary_rank_group0_u8array[cur_port] = 1;
                 tertiary_rank_group0_u8array[cur_port] = 2;
                 quanternary_rank_group0_u8array[cur_port] = 3;
                 break;
           case 8:               // 8 rank lrdimm falls through to 2 rank case
         // Rank Multiplication mode needed, CS2 & CS3 used as address lines into LRBuffer
         // RM=4 -> only 2 CS valid, each CS controls 4 ranks with CS2 & CS3 as address
         // CS0 = rank 0, 2, 4, 6;  CS1 = rank 1, 3, 5, 7
           case 2:               // 2 rank lrdimm
                 primary_rank_group0_u8array[cur_port] = 0;
                 secondary_rank_group0_u8array[cur_port] = 1;
                 tertiary_rank_group0_u8array[cur_port] = INVALID;
                 quanternary_rank_group0_u8array[cur_port] = INVALID;
                 break;
           case 1:               // 1 rank lrdimm
                 primary_rank_group0_u8array[cur_port] = 0;
                 secondary_rank_group0_u8array[cur_port] = INVALID;
                 tertiary_rank_group0_u8array[cur_port] = INVALID;
                 quanternary_rank_group0_u8array[cur_port] = INVALID;
                 break;
           default:              // not 1, 2, 4, or 8 ranks
                 primary_rank_group0_u8array[cur_port] = INVALID;
                 secondary_rank_group0_u8array[cur_port] = INVALID;
                 tertiary_rank_group0_u8array[cur_port] = INVALID;
                 quanternary_rank_group0_u8array[cur_port] = INVALID;
         }
         // dimm 1 (near socket)
         switch (num_ranks_per_dimm_u8array[cur_port][1]) {
           case 4:               // 4 rank lrdimm
                 primary_rank_group1_u8array[cur_port] = 4;
                 secondary_rank_group1_u8array[cur_port] = 5;
                 tertiary_rank_group1_u8array[cur_port] = 6;
                 quanternary_rank_group1_u8array[cur_port] = 7;
                 break;
           case 8:               // 8 rank lrdimm falls through to case 2
         // Rank Multiplication mode needed, CS6 & CS7 used as address lines into LRBuffer
         // RM=4 -> only 2 CS valid, each CS controls 4 ranks with CS6 & CS7 as address
         // CS4 = rank 0, 2, 4, 6;  CS5 = rank 1, 3, 5, 7
           case 2:               // 2 rank lrdimm, RM=0
                 primary_rank_group1_u8array[cur_port] = 4;
                 secondary_rank_group1_u8array[cur_port] = 5;
                 tertiary_rank_group1_u8array[cur_port] = INVALID;
                 quanternary_rank_group1_u8array[cur_port] = INVALID;
                 break;
           case 1:               // 1 rank lrdimm
                 primary_rank_group1_u8array[cur_port] = 4;
                 secondary_rank_group1_u8array[cur_port] = INVALID;
                 tertiary_rank_group1_u8array[cur_port] = INVALID;
                 quanternary_rank_group1_u8array[cur_port] = INVALID;
                 break;
           default:              // not 1, 2, 4, or 8 ranks
                 primary_rank_group1_u8array[cur_port] = INVALID;
                 secondary_rank_group1_u8array[cur_port] = INVALID;
                 tertiary_rank_group1_u8array[cur_port] = INVALID;
                 quanternary_rank_group1_u8array[cur_port] = INVALID;
         }

      } else { // RDIMM or CDIMM
         if ((num_ranks_per_dimm_u8array[cur_port][0] > 0) && (num_ranks_per_dimm_u8array[cur_port][1] == 0)) {
            primary_rank_group0_u8array[cur_port] = 0;
            if (num_ranks_per_dimm_u8array[cur_port][0] > 1) {
               primary_rank_group1_u8array[cur_port] = 1;
            } else {
               primary_rank_group1_u8array[cur_port] = INVALID;
            }
            if (num_ranks_per_dimm_u8array[cur_port][0] > 2) {
               primary_rank_group2_u8array[cur_port] = 2;
               primary_rank_group3_u8array[cur_port] = 3;
            } else {
               primary_rank_group2_u8array[cur_port] = INVALID;
               primary_rank_group3_u8array[cur_port] = INVALID;
            }
            secondary_rank_group0_u8array[cur_port] = INVALID;
            secondary_rank_group1_u8array[cur_port] = INVALID;
            secondary_rank_group2_u8array[cur_port] = INVALID;
            secondary_rank_group3_u8array[cur_port] = INVALID;
         } else if ((num_ranks_per_dimm_u8array[cur_port][0] > 0) && (num_ranks_per_dimm_u8array[cur_port][1] > 0)) {
            if (num_ranks_per_dimm_u8array[cur_port][0] != num_ranks_per_dimm_u8array[cur_port][1]) {
               FAPI_ERR("%s: FAILED!", PROCEDURE_NAME);
               FAPI_ERR("Plug rule violation, num_ranks_per_dimm=%d[0],%d[1] on %s PORT%d!", num_ranks_per_dimm_u8array[cur_port][0], num_ranks_per_dimm_u8array[cur_port][1], i_target_mba.toEcmdString(), cur_port);
               FAPI_SET_HWP_ERROR(rc, RC_MSS_EFF_CONFIG_RANK_GROUP_NON_MATCH_RANKS);
               return rc;
            }
            primary_rank_group0_u8array[cur_port] = 0;
            primary_rank_group1_u8array[cur_port] = 4;
            primary_rank_group2_u8array[cur_port] = INVALID;
            primary_rank_group3_u8array[cur_port] = INVALID;
            secondary_rank_group0_u8array[cur_port] = INVALID;
            secondary_rank_group1_u8array[cur_port] = INVALID;
            secondary_rank_group2_u8array[cur_port] = INVALID;
            secondary_rank_group3_u8array[cur_port] = INVALID;
            if (num_ranks_per_dimm_u8array[cur_port][0] == 2) {
               primary_rank_group2_u8array[cur_port] = 1;
               primary_rank_group3_u8array[cur_port] = 5;
            } else if (num_ranks_per_dimm_u8array[cur_port][0] == 4) {
               primary_rank_group2_u8array[cur_port] = 2;
               primary_rank_group3_u8array[cur_port] = 6;
               secondary_rank_group0_u8array[cur_port] = 1;
               secondary_rank_group1_u8array[cur_port] = 5;
               secondary_rank_group2_u8array[cur_port] = 3;
               secondary_rank_group3_u8array[cur_port] = 7;
            } else if (num_ranks_per_dimm_u8array[cur_port][0] != 1) {
               FAPI_ERR("%s: FAILED!", PROCEDURE_NAME);
               FAPI_ERR("Plug rule violation, num_ranks_per_dimm=%d[0],%d[1] on %s PORT%d!", num_ranks_per_dimm_u8array[cur_port][0], num_ranks_per_dimm_u8array[cur_port][1], i_target_mba.toEcmdString(), cur_port);
               FAPI_SET_HWP_ERROR(rc, RC_MSS_EFF_CONFIG_RANK_GROUP_NUM_RANKS_NEQ1);
               return rc;
            }
         } else if ((num_ranks_per_dimm_u8array[cur_port][0] == 0) && (num_ranks_per_dimm_u8array[cur_port][1] == 0)) {
            primary_rank_group0_u8array[cur_port] = INVALID;
            primary_rank_group1_u8array[cur_port] = INVALID;
            primary_rank_group2_u8array[cur_port] = INVALID;
            primary_rank_group3_u8array[cur_port] = INVALID;
            secondary_rank_group0_u8array[cur_port] = INVALID;
            secondary_rank_group1_u8array[cur_port] = INVALID;
            secondary_rank_group2_u8array[cur_port] = INVALID;
            secondary_rank_group3_u8array[cur_port] = INVALID;
         } else {
            FAPI_ERR("%s: FAILED!", PROCEDURE_NAME);
            FAPI_ERR("Plug rule violation, num_ranks_per_dimm=%d[0],%d[1] on %s PORT%d!", num_ranks_per_dimm_u8array[cur_port][0], num_ranks_per_dimm_u8array[cur_port][1], i_target_mba.toEcmdString(), cur_port);
            FAPI_SET_HWP_ERROR(rc, RC_MSS_EFF_CONFIG_RANK_GROUP_NO_MATCH);
            return rc;
         }
         tertiary_rank_group0_u8array[cur_port] = INVALID;
         tertiary_rank_group1_u8array[cur_port] = INVALID;
         tertiary_rank_group2_u8array[cur_port] = INVALID;
         tertiary_rank_group3_u8array[cur_port] = INVALID;
         quanternary_rank_group0_u8array[cur_port] = INVALID;
         quanternary_rank_group1_u8array[cur_port] = INVALID;
         quanternary_rank_group2_u8array[cur_port] = INVALID;
         quanternary_rank_group3_u8array[cur_port] = INVALID;
      }
      FAPI_INF("P[%02d][%02d][%02d][%02d],S[%02d][%02d][%02d][%02d],T[%02d][%02d][%02d][%02d],Q[%02d][%02d][%02d][%02d] on %s PORT%d.", primary_rank_group0_u8array[cur_port], primary_rank_group1_u8array[cur_port], primary_rank_group2_u8array[cur_port], primary_rank_group3_u8array[cur_port], secondary_rank_group0_u8array[cur_port], secondary_rank_group1_u8array[cur_port], secondary_rank_group2_u8array[cur_port], secondary_rank_group3_u8array[cur_port], tertiary_rank_group0_u8array[cur_port], tertiary_rank_group1_u8array[cur_port], tertiary_rank_group2_u8array[cur_port], tertiary_rank_group3_u8array[cur_port], quanternary_rank_group0_u8array[cur_port], quanternary_rank_group1_u8array[cur_port], quanternary_rank_group2_u8array[cur_port], quanternary_rank_group3_u8array[cur_port], i_target_mba.toEcmdString(), cur_port);
   }
   rc = FAPI_ATTR_SET(ATTR_EFF_PRIMARY_RANK_GROUP0, &i_target_mba, primary_rank_group0_u8array); if(rc) return rc;
   rc = FAPI_ATTR_SET(ATTR_EFF_PRIMARY_RANK_GROUP1, &i_target_mba, primary_rank_group1_u8array); if(rc) return rc;
   rc = FAPI_ATTR_SET(ATTR_EFF_PRIMARY_RANK_GROUP2, &i_target_mba, primary_rank_group2_u8array); if(rc) return rc;
   rc = FAPI_ATTR_SET(ATTR_EFF_PRIMARY_RANK_GROUP3, &i_target_mba, primary_rank_group3_u8array); if(rc) return rc;
   rc = FAPI_ATTR_SET(ATTR_EFF_SECONDARY_RANK_GROUP0, &i_target_mba, secondary_rank_group0_u8array); if(rc) return rc;
   rc = FAPI_ATTR_SET(ATTR_EFF_SECONDARY_RANK_GROUP1, &i_target_mba, secondary_rank_group1_u8array); if(rc) return rc;
   rc = FAPI_ATTR_SET(ATTR_EFF_SECONDARY_RANK_GROUP2, &i_target_mba, secondary_rank_group2_u8array); if(rc) return rc;
   rc = FAPI_ATTR_SET(ATTR_EFF_SECONDARY_RANK_GROUP3, &i_target_mba, secondary_rank_group3_u8array); if(rc) return rc;
   rc = FAPI_ATTR_SET(ATTR_EFF_TERTIARY_RANK_GROUP0, &i_target_mba, tertiary_rank_group0_u8array); if(rc) return rc;
   rc = FAPI_ATTR_SET(ATTR_EFF_TERTIARY_RANK_GROUP1, &i_target_mba, tertiary_rank_group1_u8array); if(rc) return rc;
   rc = FAPI_ATTR_SET(ATTR_EFF_TERTIARY_RANK_GROUP2, &i_target_mba, tertiary_rank_group2_u8array); if(rc) return rc;
   rc = FAPI_ATTR_SET(ATTR_EFF_TERTIARY_RANK_GROUP3, &i_target_mba, tertiary_rank_group3_u8array); if(rc) return rc;
   rc = FAPI_ATTR_SET(ATTR_EFF_QUATERNARY_RANK_GROUP0, &i_target_mba, quanternary_rank_group0_u8array); if(rc) return rc;
   rc = FAPI_ATTR_SET(ATTR_EFF_QUATERNARY_RANK_GROUP1, &i_target_mba, quanternary_rank_group1_u8array); if(rc) return rc;
   rc = FAPI_ATTR_SET(ATTR_EFF_QUATERNARY_RANK_GROUP2, &i_target_mba, quanternary_rank_group2_u8array); if(rc) return rc;
   rc = FAPI_ATTR_SET(ATTR_EFF_QUATERNARY_RANK_GROUP3, &i_target_mba, quanternary_rank_group3_u8array); if(rc) return rc;

   FAPI_INF("%s on %s COMPLETE", PROCEDURE_NAME, i_target_mba.toEcmdString());
   return rc;
}



} // extern "C"
