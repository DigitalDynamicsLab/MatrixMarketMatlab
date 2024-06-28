function [ err ] = mmwrite(filename,A,comment,field,precision)
%
% Function: mmwrite(filename,A,comment,field,precision)
%
%    Writes the sparse or dense matrix A to a Matrix Market (MM) 
%    formatted file.
%
% Required arguments: 
%
%                 filename  -  destination file
%
%                 A         -  sparse or full matrix
%
% Optional arguments: 
%
%                 comment   -  matrix of comments to prepend to
%                              the MM file.  To build a comment matrix,
%                              use str2mat. For example:
%
%                              comment = str2mat(' Comment 1' ,...
%                                                ' Comment 2',...
%                                                ' and so on.',...
%                                                ' to attach a date:',...
%                                                [' ',date]);
%                              If ommitted, a single line date stamp comment
%                              will be included.
%
%                 field     -  'real'
%                              'complex'
%                              'integer'
%                              'pattern'
%                              If ommitted, data will determine type.
%
%                 precision -  number of digits to display for real 
%                              or complex values
%                              If ommitted, full working precision is used.
%

err = 0;

if ( nargin == 4) 
  precision = 16;
elseif ( nargin == 3) 
  field = 'none'; % placeholder, will check after FIND-ing A
  precision = 16;
elseif ( nargin == 2) 
  comment = '';
  % Check whether there is an imaginary part:
  field = 'none'; % placeholder, will check after FIND-ing A
  precision = 16;
end

mmfile = fopen([filename],'w');
if ( mmfile == -1 )
 error('Cannot open file for output');
end

if ~strcmp(field, 'none') && ~strcmp(field, 'real') && ~strcmp(field, 'complex') && ~strcmp(field, 'integer') && ~strcmp(field, 'pattern')
     error('Cannot recognize field');
end

[M,N] = size(A);

%%%%%%%%%%%%%       This part for sparse matrices     %%%%%%%%%%%%%%%%
if ( issparse(A) )

  [I,J,V] = find(A);
  if ( sum(abs(imag(nonzeros(V)))) > 0 )
    Vreal = 0; 
  else 
    Vreal = 1; 
  end

  if (strcmp(field,'none'))
      if ( ~strcmp(field,'pattern') & Vreal )
        field = 'real'; 
      elseif ( ~ strcmp(field,'pattern') )
        field = 'complex';
      end
  end
%
% Determine symmetry:
%
  if ( M ~= N )
    symm = 'general';
    issymm = 0;
    NZ = length(V);
  else
    issymm = 1;
    NZ = length(V);
    for i=1:NZ
      if ( A(J(i),I(i)) ~= V(i) )
        issymm = 0;
        break;
      end
    end
    if ( issymm )
      symm = 'symmetric';
      ATEMP = tril(A);
      [I,J,V] = find(ATEMP);
      NZ = nnz(ATEMP);
    else
      isskew = 1;
      for i=1:NZ
        if ( A(J(i),I(i)) ~= - V(i) )
          isskew = 0;
          break;
        end
      end
      if ( isskew )
        symm = 'skew-symmetric';
        ATEMP = tril(A);
        [I,J,V] = find(ATEMP);
        NZ = nnz(ATEMP);
      elseif ( strcmp(field,'complex') )
        isherm = 1;
        for i=1:NZ
          if ( A(J(i),I(i)) ~= conj(V(i)) )
            isherm = 0;
            break;
          end
        end
        if ( isherm )
          symm = 'hermitian';
          ATEMP = tril(A);
          [I,J,V] = find(ATEMP);
          NZ = nnz(ATEMP);
        else 
          symm = 'general';
          NZ = nnz(A);
        end
      else
        symm = 'general';
        NZ = nnz(A);
      end
    end
  end

% Sparse coordinate format:

  rep = 'coordinate';


  fprintf(mmfile,'%%%%MatrixMarket matrix %s %s %s\n',rep,field,symm);
  [MC,~] = size(comment);
  if ( MC == 0 )
    fprintf(mmfile,'%% Generated %s\n', date);
  else
    for i=1:MC
      fprintf(mmfile,'%%%s\n',comment(i,:));
    end
  end
  fprintf(mmfile,'%d %d %d\n',M,N,NZ);
  cplxformat = sprintf('%%d %%d %% .%dg %% .%dg\n',precision,precision);
  realformat = sprintf('%%d %%d %% .%dg\n',precision);
  if ( strcmp(field,'real') )
     for i=1:NZ
        fprintf(mmfile,realformat,I(i),J(i),V(i));
     end
  elseif ( strcmp(field,'complex') )
     for i=1:NZ
         fprintf(mmfile,cplxformat,I(i),J(i),real(V(i)),imag(V(i)));
     end
  elseif ( strcmp(field,'integer') )
     for i=1:NZ
         fprintf(mmfile,'%d\n',I(i),J(i),V(i));
     end
  elseif ( strcmp(field,'pattern') )
     for i=1:NZ
        fprintf(mmfile,'%d %d\n',I(i),J(i));
     end
  else  
     err = -1;
     disp(['Unsupported field: ', field])
  end

%%%%%%%%%%%%%       This part for dense matrices      %%%%%%%%%%%%%%%%
else
  if ( sum(abs(imag(nonzeros(A)))) > 0 )
    Areal = 0; 
  else 
    Areal = 1; 
  end
  
  if (strcmp(field,'none'))
      if ( ~strcmp(field,'pattern') & Areal )
        field = 'real'; 
      elseif ( ~ strcmp(field,'pattern') )
        field = 'complex';
      end
  end
%
% Determine symmetry:
%
  if ( M ~= N )
    issymm = 0;
    symm = 'general';
  else
    issymm = 1;
    for j=1:N 
      for i=j+1:N
        if (A(i,j) ~= A(j,i) )
          issymm = 0;   
          break; 
        end
      end
      if ( ~ issymm ) break; end
    
    end
    if ( issymm )
      symm = 'symmetric';
    else
      isskew = 1;
      for j=1:N 
        for i=j+1:N
          if (A(i,j) ~= - A(j,i) )
            isskew = 0;   
            break; 
          end
        end
        if ( ~ isskew ) break; end
      end
      if ( isskew )
        symm = 'skew-symmetric';
      elseif ( strcmp(field,'complex') )
        isherm = 1;
        for j=1:N 
          for i=j+1:N
            if (A(i,j) ~= conj(A(j,i)) )
              isherm = 0;   
              break; 
            end
          end
          if ( ~ isherm ) break; end
        end
        if ( isherm )
          symm = 'hermitian';
        else 
          symm = 'general';
        end
      else
        symm = 'general';
      end
    end
  end

% Dense array format:

  rep = 'array';
  MC = size(comment, 1);
  fprintf(mmfile,'%%%%MatrixMarket matrix %s %s %s\n',rep,field,symm);
  for i=1:MC
    fprintf(mmfile,'%%%s\n',comment(i,:));
  end
  fprintf(mmfile,'%d %d\n',M,N);
  cplxformat = sprintf('%% .%dg %% .%dg\n', precision, precision);
  realformat = sprintf('%% .%dg\n', precision);
  if ( ~ strcmp(symm,'general') )
     rowloop = 'j';
  else 
     rowloop = '1';
  end
  if ( strcmp(field,'real') )
     for j=1:N
       for i=eval(rowloop):M
          fprintf(mmfile,realformat,A(i,j));
       end
     end
  elseif ( strcmp(field,'complex') )
     for j=1:N
       for i=eval(rowloop):M
          fprintf(mmfile,cplxformat,real(A(i,j)),imag(A(i,j)));
       end
     end
  elseif ( strcmp(field,'integer') )
     for j=1:N
       for i=eval(rowloop):M
          fprintf(mmfile,'%d\n',A(i,j));
       end
     end
  elseif ( strcmp(field,'pattern') )
     err = -2
     disp('Pattern type inconsistent with dense matrix.')
  else
     err = -2
     disp(['Unknown matrix type: ', field])
  end
end

fclose(mmfile);
