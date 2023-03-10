`timescale 1ns / 1ps

module process (
        input                clk,		    	// clock 
        input  [23:0]        in_pix,	        // valoarea pixelului de pe pozitia [in_row, in_col] din imaginea de intrare (R 23:16; G 15:8; B 7:0)
        input  [8*512-1:0]   hiding_string,     // sirul care trebuie codat
        output reg [6-1:0]       row, col, 	        // selecteaza un rand si o coloana din imagine
        output reg              out_we, 		    // activeaza scrierea pentru imaginea de iesire (write enable)
        output reg [23:0]        out_pix,	        // valoarea pixelului care va fi scrisa in imaginea de iesire pe pozitia [out_row, out_col] (R 23:16; G 15:8; B 7:0)
        output reg              gray_done,		    // semnaleaza terminarea actiunii de transformare in grayscale (activ pe 1)
        output reg              compress_done,		// semnaleaza terminarea actiunii de compresie (activ pe 1)
        output reg              encode_done        // semnaleaza terminarea actiunii de codare (activ pe 1)
    );	
	 
	 reg [6 : 0]    state = 0, next_state, i = 0, j = 0;
	 reg [7 : 0]    med_pix, min_pix, max_pix;
	 reg [7 : 0]    AVG, var;
	 reg [7 : 0]    Lm, Hm, Lm_found, Hm_found;
	 reg [6 : 0]    beta, contor, i_init, j_init, c1, c2;
	 reg [15 : 0]   suma, suma1, h_str;
	 reg [6 : 0]    contor1, i1, j1, contor2, i2, j2;
	 wire           done;
	 wire [31 : 0]  base3;
    reg  [31 : 0]  base3_done;
	 reg  [23 : 0]  pix_aux;
	 reg  [6 : 0]   c_string;
	 reg            enable = 0;
    reg  [512 * 8 - 1: 0]	 aux = 0;
	 
    //TODO - instantiate base2_to_base3 here
      base2_to_base3 STR(.base3_no(base3), .done(done), .base2_no(h_str), .en(enable), .clk(clk));
    //TODO - build your FSM here
    always @(posedge clk) begin
	     state <= next_state;
	 end
	 
	 always @(*) begin
	     out_we = 0;
		  gray_done = 0;
		  compress_done = 0;
		  encode_done = 0;
		  
		  case(state)
		  
		  // Conversia in grayscale
		  // Starile 0 - 5
		  0: begin
		      row = i;
				col = j;
				
				next_state = 1;
			  end
        
        1: begin
				// Aflu maximul din in_pix
				if(in_pix[23 : 16] >= in_pix[15 : 8] && in_pix[23 : 16] >= in_pix[7 : 0]) begin
				    max_pix = in_pix[23 : 16];
					 end
				else if(in_pix[15 : 8] >= in_pix[23 : 16] && in_pix[15 : 8] >= in_pix[7 : 0]) begin
					      max_pix = in_pix[15 : 8];
							end
					  else begin
					      max_pix = in_pix[7 : 0];
							end
							
				// Aflu minimul din in_pix
				if(in_pix[23 : 16] <= in_pix[15 : 8] && in_pix[23 : 16] <= in_pix[7 : 0]) begin
				    min_pix = in_pix[23 : 16];
					 end
				else if(in_pix[15 : 8] <= in_pix[23 : 16] && in_pix[15 : 8] <= in_pix[7 : 0]) begin
					      min_pix = in_pix[15 : 8];
							end
					  else begin
					      min_pix = in_pix[7 : 0];
							end
				
				next_state = 2;
			  end
			  
			// Formez numarul pentru grayscale
			2: begin
				med_pix = (max_pix + min_pix) / 2;
				
				out_we = 1;
				out_pix = {8'b0, med_pix, 8'b0};
				
				next_state = 3;
				end
				
			// Trec la urmatorul pixel
			3: begin
			   // Testez daca am terminat matricea
			   if(i == 63 && j == 63) begin
                next_state = 5;
					 end
            else begin
                next_state = 4;
					 end
            end
			
         // Trec la urmatorul rand / urmatoarea coloana			
         4:	begin
            if(j == 63) begin
				   i = i + 1;
               j = 0;
					
					end
				else begin
				    j = j + 1;
					 
					 end
					 next_state = 0;
            end
			
         // S-a terminat procesul de grayscale			
         5: begin
            gray_done = 1;

            next_state = 6;
				end

			// Compresia folosind AMBTC.
			// Starile: 6 - 8
			6: begin
			   contor = 0;
				suma = 0;
				i = 0;
				j = 0;
				
				i_init = 0; // init avg
				j_init = 0; // init avg
				
				i1 = 0;     // init var
				j1 = 0;     // init var
				
            i2 = 0;     // init reconstruct
				j2 = 0;     // init reconstruct

				AVG = 0;
				
				next_state = 7;
				end
			
         // Trecerea la urmatorul bloc			
			7: begin
				row = i;
				col = j;

				next_state = 8;
				end
			
         //Calculul sumei pentru AVG			
			8: begin
            if(contor < 16) begin
					 suma = suma + in_pix[23 : 8];
                contor = contor + 1;

					   if(j == j_init + 3) begin
						  if(j == 63) begin
								if(i == i_init + 3) begin
								    j_init = 0;
                            j = 0;
								    i = i + 1;
								    i_init = i;
								end
								else begin
								    i = i + 1;
									 j = j_init;
									 end
						  end
						  else begin
						      if(i == i_init + 3) begin
								   i = i_init;
							      j = j + 1;
								   j_init = j;
							   end
								else begin
								     i = i + 1;
									  j = j_init;
									  end
								 end  
						end		
						else begin
						      j = j + 1;
						     end  
					 next_state = 7;
				end
            else begin
	                 AVG = suma / 16;
						  suma = 0;
				        contor = 0;
						  
						  next_state = 9;
                 end
				end
				
         // Calculul pentru var (Include si calculul lui beta)
         // Starile: 9 - 11			
			9: begin
			   contor1 = 0;
				suma1 = 0;
				beta = 0;
				var = 0;

				if(i_init == 0) begin
					 i = 0;
					 j = j_init - 4;
				    end
				else if(j_init) begin
				    j = j_init - 4;
				 	 end
                else if(j_init == 0) begin
					      i = i_init - 4;
					      j = 60;
                     end
				 
				 next_state = 10;
				 end
			
			10: begin
			    row = i;
				 col = j;
				
				 next_state = 11;
				 end
			
			// Calculul sumei pentru var
			11: begin
			    if(contor1 < 16) begin
				     if(in_pix[23 : 8] >= AVG) begin
					      suma1 = suma1 + in_pix[23 : 8] - AVG;
							end
					  else begin
					           suma1 = suma1 + AVG - in_pix[23 : 8];
							     end							
					  contor1 = contor1 + 1;
					  
					  if(in_pix[23 : 8] >= AVG) begin
					      beta = beta + 1;
							end
					  
					  if(j == j1 + 3) begin
						  if(j == 63) begin
								if(i == i1 + 3) begin
								    j1 = 0;
                            j = 0;
								    i = i + 1;
								    i1 = i;
								end
								else begin
								    i = i + 1;
									 j = j1;
									 end
						  end
						  else begin
						      if(i == i1 + 3) begin
								   i = i1;
							      j = j + 1;
								   j1 = j;
							   end
								else begin
								     i = i + 1;
									  j = j1;
									  end
								 end  
						end		
						else begin
						      j = j + 1;
						     end  
					 next_state = 10;
				 end
             else begin
	                 var = suma1 / 16;
						  suma1 = 0;
						  contor1 = 0;
						  next_state = 12;
                  end
				 end

			// Calculul lui Lm si Hm
			12: begin	

				 Lm = AVG - ((16 * var) / (2 * (16 - beta)));
				 Hm = AVG + ((16 * var) / (2 * beta));
				 
				 next_state = 13;
				 end
         
			// Reconstructia blocului
			// Starile: 13 - 17
			13: begin
			    contor2 = 0;

				 if(i1 == 0) begin
					  i = 0;
					  j = j1 - 4;
				     end
				 else if(j1) begin
				     j = j1 - 4;
				 	  end
                 else if(j1 == 0) begin
					      i = i1 - 4;
					      j = 60;
                     end

				 next_state = 14;
				 end

			14: begin
			    row = i;
				 col = j;
             
             if(i == 64 && j == 0) begin
					  	
					  next_state = 16;
					  end
				 else begin
				     next_state = 15;
				     end
				 end

			// Reconstruirea fiecarui pixel din imagine de iesire
			// In functie de Lm si Hm.
			15: begin				 
             if(contor2 < 16) begin
                 contor2 = contor2 + 1;
					  
					  if(in_pix[23 : 8] < AVG) begin
							out_we = 1;
							out_pix = {8'b0, Lm, 8'b0};
							end
					  else begin
							out_we = 1;
							out_pix = {8'b0, Hm, 8'b0};
							end

					  if(j == j2 + 3) begin
						 if(j == 63) begin
						  	  if(i == i2 + 3) begin
								   j2 = 0;
                           j = 0;
								   i = i + 1;
								   i2 = i;
							  end
							  else begin
								   i = i + 1;
								   j = j2;
								   end
						 end
						 else begin
						     if(i == i2 + 3) begin
								   i = i2;
							      j = j + 1;
								   j2 = j;
							  end
							  else begin
								   i = i + 1;
									j = j2;
									end
							   end  
						end		
						else begin
						      j = j + 1;
						     end
							  
					 next_state = 14;
				end
            else if(contor2 == 16) begin
				        next_state = 17;
						  end	 
				 end
			
			// S-a terminat procesul de compresie.
			16: begin
				 compress_done = 1;
				 // Reinitializez toate contoarele pentru
				 // Procesul de encoding.
				 i = 0;
				 j = 0;
					  
				 i_init = 0;
				 j_init = 0;
					  
				 i1 = 0;
				 j1 = 0;
				 
				 next_state = 18;
				 end
			
         // Trecerea la urmatorul bloc.			
			17: begin
			    contor = 0;
				 suma = 0;
				 AVG = 0;
				 
				 next_state = 7;
				 end
			
			// Procesul de encode
			18: begin			    
				 contor = 0;
				 c_string = 0;
				
				 Lm_found = 255;
             Hm_found = 0;
				 c1 = 0;
				 c2 = 0;

				 next_state = 19;
				 end
					
			19: begin
				 row = i;
				 col = j;
				 
				 next_state = 20;
				 end
						
			// Caut Lm si Hm, si pozitiile lor, pentru fiecare bloc
			20: begin
             if(contor < 16) begin
					  if(in_pix[15 : 8] > Hm_found) begin
					      Hm_found = in_pix[15 : 8];
						   c2 = contor;
						   end
					  if(in_pix[15 : 8] < Lm_found) begin
					      Lm_found = in_pix[15 : 8];
						   c1 = contor;
						   end	
					  if(c1 == c2) begin
                     c1 = 0;
                     c2 = 1;
                     end
					  if(beta == 16) begin
						  c1 = 0;
						  c2 = 1;
						  Lm_found = 1;
						  Hm_found = 1;
                    end
						  
					  contor = contor + 1;
					  
					  if(j == (j_init + 3)) begin
						 if(j == 63) begin
						     if(i == (i_init + 3)) begin
								   j_init = 0;
                           j = 0;
								   i = i + 1;
								   i_init = i;
							  end
							  else begin
								   i = i + 1;
									j = j_init;
									end
						 end
						 else begin
						     if(i == (i_init + 3)) begin
								   i = i_init;
							      j = j + 1;
								   j_init = j;
							  end
							  else begin
								   i = i + 1;
									j = j_init;
									end
								 end  
					  end		
					  else begin
						   j = j + 1;
						   end
                							
					 next_state = 19;
				 end
             else if(contor == 16) begin
						    if(c2 < c1) begin
						        c2 = 0;
								  end
						    else if(c2 > c1) begin
						             c1 = 0;
									    end
						  
						  next_state = 23;
                  end
				 end
						
			// Cu Lm si Hm gasite, trec la urmatoarea etapa.
			21: begin
			    contor1 = 0;
				 c_string = 0;

				 if(i_init == 0) begin
				 	  i = 0;
					  j = j_init - 4;
				     end
				 else if(j_init) begin
				          j = j_init - 4;
				 	       end
                 else if(j_init == 0) begin
					      i = i_init - 4;
					      j = 60;
                     end
				 
				 next_state = 22;
				 end
			
			22: begin
			    row = i;
				 col = j;
				 
				 if(i == 64 && j == 0) begin
					  next_state = 25;
					  end
				 else begin
				      next_state = 24;
				      end
				 end
				 
		   // Apelarea modulului base2_to_base3
			// Am ales aici sa instantiez si h_str, fiind folosit mai departe.
			23: begin
			    enable = 1;
				 
				 h_str = hiding_string[aux +: 16];
				 
				 if(done == 1) begin
				     enable = 0;
					  base3_done = base3;
					  
					  next_state = 21;
					  end
				 else if(done != 1) begin
							 next_state = 23;
							 end
				 end

			// Encoding-ul propriu-zis
			24: begin
			    if(contor1 < 16) begin
					  pix_aux = in_pix;
					  if(contor1 != c1 && contor1 != c2) begin
                     if(base3_done[c_string +: 2] == 1) begin
							   pix_aux[15 : 8] = pix_aux[15 : 8] + 1;
								c_string = c_string + 2;
								end
							else if(base3_done[c_string +: 2] == 2) begin
							         pix_aux[15 : 8] = pix_aux[15 : 8] - 1;
										c_string = c_string + 2;
										end
							else begin
							    c_string = c_string + 2;
								 end
					  end
                 out_we = 1;
                 out_pix = pix_aux;
					  
					  contor1 = contor1 + 1;
					  
					  if(j == (j1 + 3)) begin
						 if(j == 63) begin
						     if(i == (i1 + 3)) begin
								   j1 = 0;
                           j = 0;
								   i = i + 1;
								   i1 = i;
							  end
							  else begin
								   i = i + 1;
									j = j1;
									end
						 end
						 else begin
						     if(i == (i1 + 3)) begin
								   i = i1;
							      j = j + 1;
								   j1 = j;
							  end
							  else begin
								   i = i + 1;
									j = j1;
									end
								 end  
					  end		
					  else begin
						   j = j + 1;
						   end
												 
					 next_state = 22;
				 end
             else if(contor1 == 16) begin
						  aux = aux + 16;
						  
						  next_state = 18;
                  end
				 end 
         
         // S-a terminat procesul de encoding
			25: begin
             aux = 0;
				 
				 encode_done = 1;
             end				 
			
			default: ;	 
         endcase
       end		

endmodule
